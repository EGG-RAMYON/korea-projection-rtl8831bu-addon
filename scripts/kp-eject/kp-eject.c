/* SPDX-License-Identifier: AGPL-3.0-or-later */
/* Send one SCSI START STOP UNIT (eject) to an already-enumerated CD-ROM.
 * The caller resolves the SCSI generic node below the matching USB interface.
 * Linux 3.18 sg_io_hdr_t and ARM EABI syscalls allow a static Android 4.4 build.
 */
struct sg_io_hdr {
    int interface_id, direction;
    unsigned char command_length, max_sense_length;
    unsigned short iovec_count;
    unsigned int data_length;
    void *data, *command, *sense;
    unsigned int timeout, flags;
    int pack_id;
    void *user;
    unsigned char status, masked_status, message_status, sense_length;
    unsigned short host_status, driver_status;
    int residual;
    unsigned int duration, info;
};

typedef char check_sg_io_arm_layout[sizeof(struct sg_io_hdr) == 64 ? 1 : -1];

enum { ARM_OPEN = 5, ARM_CLOSE = 6, ARM_IOCTL = 54 };
enum { SG_IO = 0x2285, SG_DXFER_NONE = -1, O_RDWR = 2, O_NONBLOCK = 04000 };

static long syscall3(long number, long arg0, long arg1, long arg2)
{
    register long r0 __asm__("r0") = arg0;
    register long r1 __asm__("r1") = arg1;
    register long r2 __asm__("r2") = arg2;
    register long r7 __asm__("r7") = number;
    __asm__ volatile("svc #0" : "+r"(r0) : "r"(r1), "r"(r2), "r"(r7) : "memory");
    return r0;
}

int kp_eject(long *stack)
{
    static unsigned char command[6] = { 0x1b, 0, 0, 0, 2, 0 };
    static unsigned char sense[32];
    static struct sg_io_hdr request;
    long fd, result;

    if (stack[0] != 2)
        return 2;
    request.interface_id = 'S';
    request.direction = SG_DXFER_NONE;
    request.command_length = sizeof(command);
    request.max_sense_length = sizeof(sense);
    request.command = command;
    request.sense = sense;
    request.timeout = 2000;
    fd = syscall3(ARM_OPEN, stack[2], O_RDWR | O_NONBLOCK, 0);
    if (fd < 0)
        return 3;
    result = syscall3(ARM_IOCTL, fd, SG_IO, (long)&request);
    syscall3(ARM_CLOSE, fd, 0, 0);
    return result < 0 || (request.info & 1) ? 4 : 0;
}

__asm__(".text\n"
        ".global _start\n"
        ".type _start, %function\n"
        "_start:\n"
        "mov r0, sp\n"
        "bl kp_eject\n"
        "mov r7, #1\n"
        "svc #0\n");
