//
//  cpuFreq.s
//  CPUDemo
//
//  Created by dev-aozhimin on 2018/2/23.
//  Copyright © 2018年 dev-aozhimin. All rights reserved.
//
/*
.text
.text
.align 4
.globl _freqTest

_freqTest:

STP x4, x5, [sp, #16 * 0]
STP x6, x7, [sp, #16 * 1]
STP x8, x9, [sp, #16 * 2]
STP x10, x11, [sp, #16 * 3]

freqTest_LOOP:

// loop 1
add     x2, x2, x1
add     x3, x3, x2
add     x4, x4, x3
add     x5, x5, x4
add     x6, x6, x5
add     x7, x7, x6
add     x8, x8, x7
add     x9, x9, x8
add     x10, x10, x9
add     x11, x11, x10
add     x12, x12, x11
add     x14, x14, x12
add     x1, x1, x14

// loop 2
add     x2, x2, x1
add     x3, x3, x2
add     x4, x4, x3
add     x5, x5, x4
add     x6, x6, x5
add     x7, x7, x6
add     x8, x8, x7
add     x9, x9, x8
add     x10, x10, x9
add     x11, x11, x10
add     x12, x12, x11
add     x14, x14, x12
add     x1, x1, x14

// loop 3
add     x2, x2, x1
add     x3, x3, x2
add     x4, x4, x3
add     x5, x5, x4
add     x6, x6, x5
add     x7, x7, x6
add     x8, x8, x7
add     x9, x9, x8
add     x10, x10, x9
add     x11, x11, x10
add     x12, x12, x11
add     x14, x14, x12
add     x1, x1, x14

// loop 4
add     x2, x2, x1
add     x3, x3, x2
add     x4, x4, x3
add     x5, x5, x4
add     x6, x6, x5
add     x7, x7, x6
add     x8, x8, x7
add     x9, x9, x8
add     x10, x10, x9
add     x11, x11, x10
add     x12, x12, x11
add     x14, x14, x12
add     x1, x1, x14

// loop 5
add     x2, x2, x1
add     x3, x3, x2
add     x4, x4, x3
add     x5, x5, x4
add     x6, x6, x5
add     x7, x7, x6
add     x8, x8, x7
add     x9, x9, x8
add     x10, x10, x9
add     x11, x11, x10
add     x12, x12, x11
add     x14, x14, x12
add     x1, x1, x14

// loop 6
add     x2, x2, x1
add     x3, x3, x2
add     x4, x4, x3
add     x5, x5, x4
add     x6, x6, x5
add     x7, x7, x6
add     x8, x8, x7
add     x9, x9, x8
add     x10, x10, x9
add     x11, x11, x10
add     x12, x12, x11
add     x14, x14, x12
add     x1, x1, x14

// loop 7
add     x2, x2, x1
add     x3, x3, x2
add     x4, x4, x3
add     x5, x5, x4
add     x6, x6, x5
add     x7, x7, x6
add     x8, x8, x7
add     x9, x9, x8
add     x10, x10, x9
add     x11, x11, x10
add     x12, x12, x11
add     x14, x14, x12
add     x1, x1, x14

// loop 8
add     x2, x2, x1
add     x3, x3, x2
add     x4, x4, x3
add     x5, x5, x4
add     x6, x6, x5
add     x7, x7, x6
add     x8, x8, x7
add     x9, x9, x8
add     x10, x10, x9
add     x11, x11, x10
add     x12, x12, x11
add     x14, x14, x12
add     x1, x1, x14

// loop 9
add     x2, x2, x1
add     x3, x3, x2
add     x4, x4, x3
add     x5, x5, x4
add     x6, x6, x5
add     x7, x7, x6
add     x8, x8, x7
add     x9, x9, x8
add     x10, x10, x9
add     x11, x11, x10
add     x12, x12, x11
add     x14, x14, x12
add     x1, x1, x14

// loop 10
add     x2, x2, x1
add     x3, x3, x2
add     x4, x4, x3
add     x5, x5, x4
add     x6, x6, x5
add     x7, x7, x6
add     x8, x8, x7
add     x9, x9, x8
add     x10, x10, x9
add     x11, x11, x10
add     x12, x12, x11
add     x14, x14, x12
add     x1, x1, x14

subs    x0, x0, #1
bne     freqTest_LOOP

RET
*/
