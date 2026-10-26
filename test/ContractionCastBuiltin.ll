; RUN: llvm-spirv %s -o %t.spv
; RUN: spirv-val %t.spv
; RUN: llvm-spirv %s -spirv-text -o - | FileCheck %s --check-prefix=ALLOW
; RUN: llvm-spirv %t.spv -to-text -o - | FileCheck %s --check-prefixes=ENTRY,LEGACY --implicit-check-not=FunctionCall
; RUN: llvm-spirv %s --spirv-ext=+SPV_KHR_float_controls2 -o %t.fc2.spv
; RUN: spirv-val %t.fc2.spv
; RUN: llvm-spirv %s --spirv-ext=+SPV_KHR_float_controls2 -spirv-text -o - | FileCheck %s --check-prefix=ALLOW
; RUN: llvm-spirv %s --spirv-ext=+SPV_KHR_float_controls2 -spirv-text -o - | FileCheck %s --check-prefixes=ENTRY,FC2

; Builtin conversions without execution-mode metadata need the same rounding protection as
; fptrunc/fpext, including explicit rounding modes and vector conversions.
; ENTRY-DAG: EntryPoint 6 [[SCALAR:[0-9]+]] "scalar"
; ENTRY-DAG: EntryPoint 6 [[VECTOR:[0-9]+]] "vector"
; ENTRY-DAG: EntryPoint 6 [[ROUNDED:[0-9]+]] "rounded"
; LEGACY-DAG: ExecutionMode [[SCALAR]] 31
; LEGACY-DAG: ExecutionMode [[VECTOR]] 31
; LEGACY-DAG: ExecutionMode [[ROUNDED]] 31
; FC2-DAG: TypeFloat [[HALF:[0-9]+]] 16
; FC2-DAG: TypeFloat [[FLOAT:[0-9]+]] 32
; FC2-DAG: Constant {{[0-9]+}} [[ZERO:[0-9]+]] 0
; FC2-DAG: ExecutionModeId [[SCALAR]] 6028 [[HALF]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[SCALAR]] 6028 [[FLOAT]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[VECTOR]] 6028 [[HALF]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[VECTOR]] 6028 [[FLOAT]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[ROUNDED]] 6028 [[HALF]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[ROUNDED]] 6028 [[FLOAT]] [[ZERO]]

; Fully permitted builtin conversions must not introduce kernel restrictions.
; ALLOW: EntryPoint 6 [[ALLOWED:[0-9]+]] "allowed"
; ALLOW-NOT: ExecutionMode{{(Id)?}} [[ALLOWED]] {{(31|6028)}}

target triple = "spir64"

define spir_kernel void @scalar(float %x, ptr addrspace(1) %out) {
  %h = call spir_func half @_Z12convert_halff(float %x)
  %f = call spir_func float @_Z13convert_floatDh(half %h)
  store float %f, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @vector(<2 x float> %x, ptr addrspace(1) %out) {
  %h = call spir_func <2 x half> @_Z13convert_half2Dv2_f(<2 x float> %x)
  %f = call spir_func <2 x float> @_Z14convert_float2Dv2_Dh(<2 x half> %h)
  store <2 x float> %f, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @rounded(float %x, ptr addrspace(1) %out) {
  %h = call spir_func half @_Z16convert_half_rtef(float %x)
  %f = call spir_func float @_Z13convert_floatDh(half %h)
  store float %f, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @allowed(float %x, ptr addrspace(1) %out) {
  %h = call contract spir_func half @_Z12convert_halff(float %x)
  %f = call contract spir_func float @_Z13convert_floatDh(half %h)
  store float %f, ptr addrspace(1) %out
  ret void
}

declare spir_func half @_Z12convert_halff(float)
declare spir_func half @_Z16convert_half_rtef(float)
declare spir_func float @_Z13convert_floatDh(half)
declare spir_func <2 x half> @_Z13convert_half2Dv2_f(<2 x float>)
declare spir_func <2 x float> @_Z14convert_float2Dv2_Dh(<2 x half>)

!opencl.ocl.version = !{!0}
!0 = !{i32 2, i32 0}
