/*
Wavelet Stage Driver

Copyright (C) 2019 by Shane W. Colton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

// Include Headers -----------------------------------------------------------------------------------------------------

#include "wavelet.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

// Public Global Variables ---------------------------------------------------------------------------------------------

// Private Global Variables --------------------------------------------------------------------------------------------

// Wavelet S1
u32 * debug_XX1_px_count_trig = (u32 *)(0xA0001000);
u32 * debug_core_XX1_addr  = (u32 *)(0xA0001004);
u32 * debug_core_HH1_data = (u32 *)(0xA0001010);
u32 * debug_core_HL1_data = (u32 *)(0xA0001014);
u32 * debug_core_LH1_data = (u32 *)(0xA0001018);
u32 * debug_core_LL1_data = (u32 *)(0xA000101C);

// Wavelet S2
u32 * debug_XX2_px_count_trig = (u32 *)(0xA0002000);
u32 * debug_core_XX2_addr  = (u32 *)(0xA0002004);
u32 * debug_core_HH2_data = (u32 *)(0xA0002010);
u32 * debug_core_HL2_data = (u32 *)(0xA0002014);
u32 * debug_core_LH2_data = (u32 *)(0xA0002018);
u32 * debug_core_LL2_data = (u32 *)(0xA000201C);

// Wavelet S3
u32 * debug_XX3_px_count_trig = (u32 *)(0xA0003000);
u32 * debug_core_XX3_addr  = (u32 *)(0xA0003004);
u32 * debug_core_HH3_data = (u32 *)(0xA0003010);
u32 * debug_core_HL3_data = (u32 *)(0xA0003014);
u32 * debug_core_LH3_data = (u32 *)(0xA0003018);
u32 * debug_core_LL3_data = (u32 *)(0xA000301C);

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

// Private Function Definitions ----------------------------------------------------------------------------------------
