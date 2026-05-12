#include "cpu.h"
#include "memory.h"

void cpu_init(CPU *cpu) {
    cpu->A = cpu->F = 0;
    cpu->B = cpu->C = 0;
    cpu->D = cpu->E = 0;
    cpu->H = cpu->L = 0;
    cpu->SP = 0xFFFE;
    cpu->PC = 0x0100;
    cpu->halted = 0;
    cpu->ime = 0;
}

static inline uint8_t read_pc8(CPU *cpu, Memory *mem) {
    return mem_read(mem, cpu->PC++);
}

void cpu_step(CPU *cpu, void *mem_ptr) {
    Memory *mem = (Memory *)mem_ptr;
    uint8_t opcode = read_pc8(cpu, mem);
    
    switch (opcode) {
        case 0x00:
            break;
        case 0x01:
            cpu->C = read_pc8(cpu, mem);
            cpu->B = read_pc8(cpu, mem);
            break;
        case 0x02:
            break;
        case 0xC3: {
            uint8_t lo = read_pc8(cpu, mem);
            uint8_t hi = read_pc8(cpu, mem);
            cpu->PC = (hi << 8) | lo;
            break;
        }
        case 0xAF:
            cpu->A = 0;
            cpu->F = 0;
            break;
        case 0x3E: {
            uint8_t val = read_pc8(cpu, mem);
            cpu->A = val;
            break;
        }
        case 0x0E: {
            cpu->C = read_pc8(cpu, mem);
            break;
        }
        case 0x06: {
            cpu->B = read_pc8(cpu, mem);
            break;
        }
        default:
            break;
    }
}