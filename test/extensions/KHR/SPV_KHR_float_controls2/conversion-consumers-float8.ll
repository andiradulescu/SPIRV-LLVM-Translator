; RUN: llvm-spirv %s --spirv-ext=+SPV_KHR_float_controls2,+SPV_EXT_float8 -o %t.spv
; RUN: spirv-val %t.spv
; RUN: llvm-spirv -r --spirv-target-env=SPV-IR %t.spv -o %t.bc
; RUN: llvm-dis %t.bc -o - | FileCheck %s
; RUN: llvm-spirv %t.bc --spirv-ext=+SPV_KHR_float_controls2,+SPV_EXT_float8 -o %t.back.spv
; RUN: spirv-val %t.back.spv
; RUN: llvm-spirv -r --spirv-target-env=SPV-IR %t.back.spv -o %t.back.bc
; RUN: llvm-dis %t.back.bc -o - | FileCheck %s

; Internal FP8 builtins also become OpFConvert. Consumers must not grant
; contraction or reassociation across a strict scalar or vector conversion.
; CHECK-LABEL: define spir_kernel void @strict_vector(
; CHECK: call spir_func <2 x half> @{{.*}}__builtin_spirv_ConvertE5M2ToFP16EXT
; CHECK: fmul <2 x half>

; Permissions shared by the conversion and its consumer remain available.
; CHECK-LABEL: define spir_kernel void @allowed(
; CHECK: call contract spir_func half @{{.*}}__builtin_spirv_ConvertE4M3ToFP16EXT
; CHECK: fmul contract half

; The producer may be translated after its consumer due to block layout.
; CHECK-LABEL: define spir_kernel void @late_conversion(
; CHECK: call spir_func half @{{.*}}__builtin_spirv_ConvertE4M3ToFP16EXT
; CHECK: fmul half

target triple = "spir64"

define spir_kernel void @strict_vector(<2 x i8> %x, <2 x half> %y, ptr addrspace(1) %out) {
  %h = call spir_func <2 x half> @_Z36__builtin_spirv_ConvertE5M2ToFP16EXTDv2_c(<2 x i8> %x)
  %m = fmul reassoc <2 x half> %y, %h
  store <2 x half> %m, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @allowed(i8 %x, half %y, ptr addrspace(1) %out) {
  %h = call contract spir_func half @_Z36__builtin_spirv_ConvertE4M3ToFP16EXTc(i8 %x)
  %m = fmul contract half %h, %y
  store half %m, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @late_conversion(i8 %x, half %y, ptr addrspace(1) %out) {
entry:
  br label %def
use:
  %m = fmul contract half %h, %y
  store half %m, ptr addrspace(1) %out
  ret void
def:
  %h = call spir_func half @_Z36__builtin_spirv_ConvertE4M3ToFP16EXTc(i8 %x)
  br label %use
}

declare spir_func half @_Z36__builtin_spirv_ConvertE4M3ToFP16EXTc(i8)
declare spir_func <2 x half> @_Z36__builtin_spirv_ConvertE5M2ToFP16EXTDv2_c(<2 x i8>)
