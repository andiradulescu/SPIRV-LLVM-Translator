; RUN: llvm-spirv %s --spirv-ext=+SPV_KHR_float_controls2 --spirv-max-version=1.2 -o %t.spv
; RUN: spirv-val --target-env spv1.2 %t.spv
; RUN: llvm-spirv -r --spirv-target-env=SPV-IR %t.spv -o %t.bc
; RUN: llvm-dis %t.bc -o - | FileCheck %s
; RUN: llvm-spirv %t.bc --spirv-ext=+SPV_KHR_float_controls2 -o %t.back.spv
; RUN: spirv-val %t.back.spv
; RUN: llvm-spirv -r --spirv-target-env=SPV-IR %t.back.spv -o %t.back.bc
; RUN: llvm-dis %t.back.bc -o - | FileCheck %s

; Arithmetic consumers must not grant rewrites across a strict conversion,
; regardless of the operand position or whether the conversion was a builtin.
; CHECK-LABEL: define spir_kernel void @narrow_right(
; CHECK: fptrunc float
; CHECK: fmul half
; CHECK-LABEL: define spir_kernel void @wide(
; CHECK: fpext half
; CHECK: fdiv nnan ninf nsz arcp float
; Permissions shared by both instructions remain available.
; CHECK-LABEL: define spir_kernel void @allowed(
; CHECK: fptrunc contract float
; CHECK: fmul contract half

; Block layout need not follow dominance order. A producer translated later
; must impose the same restriction, including when it is a builtin call.
; CHECK-LABEL: define spir_kernel void @late_cast(
; CHECK: fptrunc float
; CHECK: fmul half
; CHECK-LABEL: define spir_kernel void @late_builtin(
; CHECK: fptrunc float
; CHECK: fmul half
; CHECK-LABEL: define spir_kernel void @late_allowed(
; CHECK: fptrunc contract float
; CHECK: fmul contract half

; Constrained conversions use the same opcode and must not regress when
; identifying producers from LLVM instructions instead of translated values.
; CHECK-LABEL: define spir_kernel void @late_constrained_narrow(
; CHECK: fptrunc float
; CHECK: fmul half
; CHECK-LABEL: define spir_kernel void @late_constrained_wide(
; CHECK: fpext half
; CHECK: fmul float

target triple = "spir64"

define spir_kernel void @narrow_right(float %x, half %y, ptr addrspace(1) %out) {
  %h = fptrunc float %x to half
  %m = fmul reassoc half %y, %h
  store half %m, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @wide(half %x, float %y, ptr addrspace(1) %out) {
  %f = fpext half %x to float
  %d = fdiv fast float %y, %f
  store float %d, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @allowed(float %x, half %y, ptr addrspace(1) %out) {
  %h = fptrunc contract float %x to half
  %m = fmul contract half %h, %y
  store half %m, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @late_cast(float %x, half %y, ptr addrspace(1) %out) {
entry:
  br label %def
use:
  %m = fmul contract half %h, %y
  store half %m, ptr addrspace(1) %out
  ret void
def:
  %h = fptrunc float %x to half
  br label %use
}

define spir_kernel void @late_builtin(float %x, half %y, ptr addrspace(1) %out) {
entry:
  br label %def
use:
  %m = fmul contract half %h, %y
  store half %m, ptr addrspace(1) %out
  ret void
def:
  %h = call spir_func half @_Z12convert_halff(float %x)
  br label %use
}

define spir_kernel void @late_allowed(float %x, half %y, ptr addrspace(1) %out) {
entry:
  br label %def
use:
  %m = fmul contract half %h, %y
  store half %m, ptr addrspace(1) %out
  ret void
def:
  %h = call contract spir_func half @_Z12convert_halff(float %x)
  br label %use
}

define spir_kernel void @late_constrained_narrow(float %x, half %y, ptr addrspace(1) %out) {
entry:
  br label %def
use:
  %m = fmul contract half %h, %y
  store half %m, ptr addrspace(1) %out
  ret void
def:
  %h = call half @llvm.experimental.constrained.fptrunc.f16.f32(float %x, metadata !"round.dynamic", metadata !"fpexcept.ignore")
  br label %use
}

define spir_kernel void @late_constrained_wide(half %x, float %y, ptr addrspace(1) %out) {
entry:
  br label %def
use:
  %m = fmul contract float %h, %y
  store float %m, ptr addrspace(1) %out
  ret void
def:
  %h = call float @llvm.experimental.constrained.fpext.f32.f16(half %x, metadata !"fpexcept.ignore")
  br label %use
}

declare half @llvm.experimental.constrained.fptrunc.f16.f32(float, metadata, metadata)
declare float @llvm.experimental.constrained.fpext.f32.f16(half, metadata)
declare spir_func half @_Z12convert_halff(float)

!opencl.ocl.version = !{!0}
!0 = !{i32 2, i32 0}
