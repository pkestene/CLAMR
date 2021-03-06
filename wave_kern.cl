/*
 *  Copyright (c) 2011-2019, Triad National Security, LLC.
 *  All rights Reserved.
 *
 *  CLAMR -- LA-CC-11-094
 *
 *  Copyright 2011-2019. Triad National Security, LLC. This software was produced 
 *  under U.S. Government contract 89233218CNA000001 for Los Alamos National 
 *  Laboratory (LANL), which is operated by Triad National Security, LLC 
 *  for the U.S. Department of Energy. The U.S. Government has rights to use, 
 *  reproduce, and distribute this software.  NEITHER THE GOVERNMENT NOR
 *  TRIAD NATIONAL SECURITY, LLC MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR 
 *  ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.  If software is modified
 *  to produce derivative works, such modified software should be clearly marked,
 *  so as not to confuse it with the version available from LANL.
 *
 *  Additionally, redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the Triad National Security, LLC, Los Alamos 
 *       National Laboratory, LANL, the U.S. Government, nor the names of its 
 *       contributors may be used to endorse or promote products derived from 
 *       this software without specific prior written permission.
 *  
 *  THIS SOFTWARE IS PROVIDED BY THE TRIAD NATIONAL SECURITY, LLC AND 
 *  CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT 
 *  NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 *  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL TRIAD NATIONAL
 *  SECURITY, LLC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 *  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 *  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *  
 *  CLAMR -- LA-CC-11-094
 *  This research code is being developed as part of the 
 *  2011 X Division Summer Workshop for the express purpose
 *  of a collaborative code for development of ideas in
 *  the implementation of AMR codes for Exascale platforms
 *  
 *  AMR implementation of the Wave code previously developed
 *  as a demonstration code for regular grids on Exascale platforms
 *  as part of the Supercomputing Challenge and Los Alamos 
 *  National Laboratory
 *  
 *  Authors: Bob Robey       XCP-2   brobey@lanl.gov
 *           Neal Davis              davis68@lanl.gov, davis68@illinois.edu
 *           David Nicholaeff        dnic@lanl.gov, mtrxknight@aol.com
 *           Dennis Trujillo         dptrujillo@lanl.gov, dptru10@gmail.com
 * 
 */

#ifndef GPU_DOUBLE_SUPPORT
#define GPU_DOUBLE_SUPPORT
#ifdef HAVE_CL_DOUBLE
#pragma OPENCL EXTENSION cl_khr_fp64 : enable
typedef double  real;
typedef double2 real2;
#else
typedef float   real;
typedef float2  real2;
#endif
#endif

#ifndef max
#define max(a,b) ((a) > (b) ? (a) : (b))
#endif
#ifndef fabs
#define fabs(a) ( (a) < 0 ? -(a) : a)
#endif

void reduction_max_within_tile1(__local  real  *tile);
void reduction_max_within_tile2(__local  real2  *tile);
void reduction_minmax_within_tile4(__local  int4  *tile);

void reduction_minmax_within_tile4(__local  int4  *tile)
{
    const unsigned int tiX  = get_local_id(0);
    const unsigned int ntX  = get_local_size(0);

    for (int offset=ntX>>1; offset > MIN_REDUCE_SYNC_SIZE; offset >>= 1){
      if (tiX < offset){
        if (tile[tiX+offset].s0 < tile[tiX].s0) tile[tiX].s0 = tile[tiX+offset].s0;
        if (tile[tiX+offset].s1 > tile[tiX].s1) tile[tiX].s1 = tile[tiX+offset].s1;
        if (tile[tiX+offset].s2 < tile[tiX].s2) tile[tiX].s2 = tile[tiX+offset].s2;
        if (tile[tiX+offset].s3 > tile[tiX].s3) tile[tiX].s3 = tile[tiX+offset].s3;
      }
      barrier(CLK_LOCAL_MEM_FENCE);
    }

    if (tiX < MIN_REDUCE_SYNC_SIZE)
    {
        for (int offset = MIN_REDUCE_SYNC_SIZE; offset > 1; offset >>= 1)
        {
            if (tile[tiX + offset].s0 < tile[tiX].s0) tile[tiX].s0 = tile[tiX + offset].s0;
            if (tile[tiX + offset].s1 > tile[tiX].s1) tile[tiX].s1 = tile[tiX + offset].s1;
            if (tile[tiX + offset].s2 < tile[tiX].s2) tile[tiX].s2 = tile[tiX + offset].s2;
            if (tile[tiX + offset].s3 > tile[tiX].s3) tile[tiX].s3 = tile[tiX + offset].s3;
            barrier(CLK_LOCAL_MEM_FENCE);
        }

        if (tile[tiX + 1].s0 < tile[tiX].s0) tile[tiX].s0 = tile[tiX + 1].s0;
        if (tile[tiX + 1].s1 > tile[tiX].s1) tile[tiX].s1 = tile[tiX + 1].s1;
        if (tile[tiX + 1].s2 < tile[tiX].s2) tile[tiX].s2 = tile[tiX + 1].s2;
        if (tile[tiX + 1].s3 > tile[tiX].s3) tile[tiX].s3 = tile[tiX + 1].s3;
    }
}

real MAX(real a, real b)
{
    return max(a, b);
}

#define REDUCE_IN_TILE(operation, _tile_arr)                                    \
    for (int offset = ntX >> 1; offset > MIN_REDUCE_SYNC_SIZE; offset >>= 1)    \
    {                                                                           \
        if (tiX < offset)                                                       \
        {                                                                       \
            _tile_arr[tiX] = operation(_tile_arr[tiX], _tile_arr[tiX+offset]);  \
        }                                                                       \
        barrier(CLK_LOCAL_MEM_FENCE);                                           \
    }                                                                           \
    if (tiX < MIN_REDUCE_SYNC_SIZE)                                             \
    {                                                                           \
        for (int offset = MIN_REDUCE_SYNC_SIZE; offset > 1; offset >>= 1)       \
        {                                                                       \
            _tile_arr[tiX] = operation(_tile_arr[tiX], _tile_arr[tiX+offset]);  \
            barrier(CLK_LOCAL_MEM_FENCE);                                       \
        }                                                                       \
        _tile_arr[tiX] = operation(_tile_arr[tiX], _tile_arr[tiX+1]);           \
    }

void reduction_max_within_tile1(__local  real  *tile) 
{
   const unsigned int tiX  = get_local_id(0);
   const unsigned int ntX  = get_local_size(0);

   REDUCE_IN_TILE(MAX, tile);
}

void reduction_max_within_tile2(__local  real2  *tile) 
{
    const unsigned int tiX  = get_local_id(0);
    const unsigned int ntX  = get_local_size(0);

    for (int offset = ntX >> 1; offset > MIN_REDUCE_SYNC_SIZE; offset >>= 1)
    {
        if (tiX < offset)
        {
            if (tile[tiX+offset].s0 > tile[tiX].s0) tile[tiX].s0 = tile[tiX+offset].s0;
            if (tile[tiX+offset].s1 > tile[tiX].s1) tile[tiX].s1 = tile[tiX+offset].s1;
        }
        barrier(CLK_LOCAL_MEM_FENCE);
    }
    if (tiX < MIN_REDUCE_SYNC_SIZE)
    {
        for (int offset = MIN_REDUCE_SYNC_SIZE; offset > 1; offset >>= 1)
        {
            if (tile[tiX + offset].s0 > tile[tiX].s0) tile[tiX].s0 = tile[tiX + offset].s0;
            if (tile[tiX + offset].s1 > tile[tiX].s1) tile[tiX].s1 = tile[tiX + offset].s1;
            barrier(CLK_LOCAL_MEM_FENCE);
        }
        if (tile[tiX + 1].s0 > tile[tiX].s0) tile[tiX].s0 = tile[tiX + 1].s0;
        if (tile[tiX + 1].s1 > tile[tiX].s1) tile[tiX].s1 = tile[tiX + 1].s1;
    }
}


