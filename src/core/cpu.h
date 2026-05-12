#ifndef CPU_H
#define CPU_H

#include "../shared/types.h"

typedef struct {
    uint8_t A, F;
    uint8_t B, C;
    uint8_t D, E;
    uint8_t H, L;
    
    uint16_t SP;
    uint16_t PC;
    
    int halted;
    int ime;
} CPU;

void cpu_init(CPU *cpu);
void cpu_step(CPU *cpu, void *mem);

#endif