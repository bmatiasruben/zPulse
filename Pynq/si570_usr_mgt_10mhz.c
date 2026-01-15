// si570_usr_mgt_10mhz.c
// Set USER MGT Si570 on ZCU102 to 10 MHz from userspace.
//
// Usage: sudo ./si570_usr_mgt_10mhz <i2c-bus-number>
// Example: sudo ./si570_usr_mgt_10mhz 8
//
// Based on Linux clk-si570 driver logic (simplified, no error handling niceties).

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/i2c-dev.h>
#include <errno.h>
#include <string.h>

#define SI570_ADDR           0x5d

// Registers
#define SI570_REG_HS_N1      7
#define SI570_REG_N1_RFREQ0  8
#define SI570_REG_RFREQ1     9
#define SI570_REG_RFREQ2     10
#define SI570_REG_RFREQ3     11
#define SI570_REG_RFREQ4     12
#define SI570_REG_CONTROL    135
#define SI570_REG_FREEZE_DCO 137

// Bit fields
#define HS_DIV_SHIFT         5
#define HS_DIV_MASK          0xe0
#define HS_DIV_OFFSET        4
#define N1_6_2_MASK          0x1f
#define N1_1_0_MASK          0xc0
#define RFREQ_37_32_MASK     0x3f

#define SI570_CNTRL_RECALL   (1 << 0)
#define SI570_CNTRL_NEWFREQ  (1 << 6)
#define SI570_FREEZE_DCO     (1 << 4)

// Limits
#define FDCO_MIN             4850000000LL
#define FDCO_MAX             5670000000LL

// ZCU102 USER MGT Si570 factory output
#define FACTORY_FOUT         156250000ULL  // 156.25 MHz
#define TARGET_FOUT          10000000UL    // 10 MHz

static int i2c_read_regs(int fd, uint8_t reg, uint8_t *buf, size_t len)
{
    if (write(fd, &reg, 1) != 1) {
        perror("write (set reg addr)");
        return -1;
    }
    if (read(fd, buf, len) != (ssize_t)len) {
        perror("read (regs)");
        return -1;
    }
    return 0;
}

static int i2c_write_regs(int fd, uint8_t reg, const uint8_t *buf, size_t len)
{
    uint8_t tmp[1 + 6]; // enough for 1 + up to 5 bytes
    if (len > 6) {
        fprintf(stderr, "len too large\n");
        return -1;
    }
    tmp[0] = reg;
    memcpy(&tmp[1], buf, len);
    if (write(fd, tmp, 1 + len) != (ssize_t)(1 + len)) {
        perror("write (regs)");
        return -1;
    }
    return 0;
}

// Read HS_DIV, N1, RFREQ from regs 7-12
static int si570_get_divs(int fd, uint64_t *rfreq, unsigned int *n1, unsigned int *hs_div)
{
    uint8_t reg[6];
    uint64_t tmp;

    if (i2c_read_regs(fd, SI570_REG_HS_N1, reg, sizeof(reg)) < 0)
        return -1;

    *hs_div = ((reg[0] & HS_DIV_MASK) >> HS_DIV_SHIFT) + HS_DIV_OFFSET;

    *n1 = ((reg[0] & N1_6_2_MASK) << 2) + ((reg[1] & N1_1_0_MASK) >> 6) + 1;
    if (*n1 > 1)
        *n1 &= ~1; // ensure even, per datasheet

    tmp  = reg[1] & RFREQ_37_32_MASK;
    tmp  = (tmp << 8) + reg[2];
    tmp  = (tmp << 8) + reg[3];
    tmp  = (tmp << 8) + reg[4];
    tmp  = (tmp << 8) + reg[5];
    *rfreq = tmp;

    return 0;
}

// Compute fxtal from factory output and current dividers
static int si570_get_fxtal(uint64_t *fxtal, uint64_t factory_fout,
                           unsigned int n1, unsigned int hs_div, uint64_t rfreq)
{
    uint64_t fdco = factory_fout * n1 * hs_div;

    if (fdco >= (1ULL << 36))
        *fxtal = (fdco << 24) / (rfreq >> 4);
    else
        *fxtal = (fdco << 28) / rfreq;

    return 0;
}

// Calculate n1, hs_div, rfreq for target frequency
static int si570_calc_divs(uint64_t target_freq, uint64_t fxtal,
                           uint64_t *out_rfreq, unsigned int *out_n1, unsigned int *out_hs_div)
{
    static const uint8_t hs_div_values[] = { 11, 9, 7, 6, 5, 4 };
    uint64_t best_fdco = (uint64_t)-1;
    int i;

    for (i = 0; i < (int)(sizeof(hs_div_values)/sizeof(hs_div_values[0])); i++) {
        unsigned int hs_div = hs_div_values[i];
        unsigned int n1;
        uint64_t fdco;

        // lowest possible n1
        n1 = FDCO_MIN / hs_div / target_freq;
        if (!n1 || (n1 & 1))
            n1++;

        while (n1 <= 128) {
            fdco = target_freq * (uint64_t)hs_div * (uint64_t)n1;
            if (fdco > FDCO_MAX)
                break;
            if (fdco >= FDCO_MIN && fdco < best_fdco) {
                *out_n1 = n1;
                *out_hs_div = hs_div;
                *out_rfreq = (fdco << 28) / fxtal;
                best_fdco = fdco;
            }
            n1 += (n1 == 1 ? 1 : 2);
        }
    }

    if (best_fdco == (uint64_t)-1) {
        fprintf(stderr, "No valid FDCO found\n");
        return -1;
    }
    return 0;
}

// Write HS_DIV + N1 + RFREQ back to device with proper freeze / newfreq sequence
static int si570_set_frequency(int fd, uint64_t fxtal, uint64_t target_freq)
{
    int ret;
    uint64_t rfreq;
    unsigned int n1, hs_div;
    uint8_t buf[5];
    uint8_t val;

    ret = si570_calc_divs(target_freq, fxtal, &rfreq, &n1, &hs_div);
    if (ret < 0)
        return ret;

    // Freeze DCO
    val = SI570_FREEZE_DCO;
    if (i2c_write_regs(fd, SI570_REG_FREEZE_DCO, &val, 1) < 0)
        return -1;

    // Write HS_DIV & N1 high bits into reg 7
    val = ((hs_div - HS_DIV_OFFSET) << HS_DIV_SHIFT) |
          (((n1 - 1) >> 2) & N1_6_2_MASK);
    if (i2c_write_regs(fd, SI570_REG_HS_N1, &val, 1) < 0)
        return -1;

    // Write N1 low bits + RFREQ[37:32] etc. into regs 8-12
    buf[0] = ((n1 - 1) << 6) | ((rfreq >> 32) & RFREQ_37_32_MASK);
    buf[1] = (rfreq >> 24) & 0xff;
    buf[2] = (rfreq >> 16) & 0xff;
    buf[3] = (rfreq >> 8)  & 0xff;
    buf[4] =  rfreq        & 0xff;

    if (i2c_write_regs(fd, SI570_REG_N1_RFREQ0, buf, 5) < 0)
        return -1;

    // Unfreeze DCO
    val = 0;
    if (i2c_write_regs(fd, SI570_REG_FREEZE_DCO, &val, 1) < 0)
        return -1;

    // Assert NEWFREQ
    val = SI570_CNTRL_NEWFREQ;
    if (i2c_write_regs(fd, SI570_REG_CONTROL, &val, 1) < 0)
        return -1;

    // Datasheet: up to 10 ms to settle
    usleep(11000);

    return 0;
}

int main(int argc, char **argv)
{
    int fd;
    char devname[32];
    int bus;
    uint8_t val;
    uint64_t rfreq, fxtal;
    unsigned int n1, hs_div;

    if (argc != 2) {
        fprintf(stderr, "Usage: %s <i2c-bus-number>\n", argv[0]);
        return 1;
    }

    bus = atoi(argv[1]);
    snprintf(devname, sizeof(devname), "/dev/i2c-%d", bus);

    fd = open(devname, O_RDWR);
    if (fd < 0) {
        perror("open i2c");
        return 1;
    }

    if (ioctl(fd, I2C_SLAVE_FORCE, SI570_ADDR) < 0) {
        perror("ioctl I2C_SLAVE_FORCE");
        close(fd);
        return 1;
    }

    printf("Using %s, addr 0x%02x (USER MGT Si570) -> 10 MHz\n", devname, SI570_ADDR);

    // Optional: recall factory config into RAM (Control reg bit 0)
    val = SI570_CNTRL_RECALL;
    if (i2c_write_regs(fd, SI570_REG_CONTROL, &val, 1) < 0) {
        fprintf(stderr, "Failed to send RECALL, continuing anyway\n");
    } else {
        usleep(10000); // 10ms
    }

    if (si570_get_divs(fd, &rfreq, &n1, &hs_div) < 0) {
        fprintf(stderr, "si570_get_divs failed\n");
        close(fd);
        return 1;
    }

    printf("Factory divs: hs_div=%u, n1=%u, rfreq=0x%010llx\n",
           hs_div, n1, (unsigned long long)rfreq);

    if (si570_get_fxtal(&fxtal, FACTORY_FOUT, n1, hs_div, rfreq) < 0) {
        fprintf(stderr, "si570_get_fxtal failed\n");
        close(fd);
        return 1;
    }

    printf("Computed fxtal ~ %llu Hz\n", (unsigned long long)fxtal);

    if (si570_set_frequency(fd, fxtal, TARGET_FOUT) < 0) {
        fprintf(stderr, "si570_set_frequency failed\n");
        close(fd);
        return 1;
    }

    printf("USER MGT Si570 programmed to %u Hz (10 MHz)\n", TARGET_FOUT);

    close(fd);
    return 0;
}
