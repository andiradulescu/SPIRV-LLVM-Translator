; RUN: llvm-spirv %s --spirv-ext=+SPV_KHR_float_controls2 --spirv-max-version=1.2 -o %t.12.spv
; RUN: spirv-val --target-env spv1.2 %t.12.spv
; RUN: llvm-spirv %s --spirv-ext=+SPV_KHR_float_controls2 --spirv-max-version=1.5 -o %t.15.spv
; RUN: spirv-val --target-env spv1.5 %t.15.spv
; RUN: llvm-spirv %s --spirv-ext=+SPV_KHR_float_controls2 -o %t.spv
; RUN: spirv-val %t.spv
; RUN: llvm-spirv -r --spirv-target-env=SPV-IR %t.spv -o %t.bc
; RUN: llvm-dis %t.bc -o - | FileCheck %s
; RUN: llvm-spirv %s --spirv-ext=+SPV_KHR_float_controls2 --spirv-fp-contract=off -o %t.off.spv
; RUN: spirv-val %t.off.spv
; RUN: llvm-spirv -r --spirv-target-env=SPV-IR %t.off.spv -o %t.off.bc
; RUN: llvm-dis %t.off.bc -o - | FileCheck %s --check-prefix=OFF --implicit-check-not=' contract ' --implicit-check-not=' reassoc '

; RUN: llvm-spirv %t.bc --spirv-ext=+SPV_KHR_float_controls2 --spirv-fp-contract=off -o %t.roundtrip.off.spv
; RUN: spirv-val %t.roundtrip.off.spv
; RUN: llvm-spirv -r --spirv-target-env=SPV-IR %t.roundtrip.off.spv -o %t.roundtrip.off.bc
; RUN: llvm-dis %t.roundtrip.off.bc -o - | FileCheck %s --check-prefix=OFF --implicit-check-not=' contract ' --implicit-check-not=' reassoc '

; A permissive consumer must not grant contraction across a strict producer.
; CHECK-LABEL: define spir_kernel void @mixed(
; CHECK: fptrunc float
; CHECK: fpext half
; CHECK-LABEL: define spir_kernel void @mixed_fast(
; CHECK: fptrunc float
; CHECK: fpext nnan ninf nsz arcp half
; CHECK-LABEL: define spir_kernel void @mixed_reassoc(
; CHECK: fptrunc float
; CHECK: fpext half
; CHECK-LABEL: define spir_kernel void @allowed(
; CHECK: fptrunc contract float
; CHECK: fpext contract half
; A strict arithmetic producer also needs protection when explicit defaults
; would otherwise restore the permission removed from its consuming cast.
; CHECK-LABEL: define spir_kernel void @strict_division(
; CHECK: fdiv float
; CHECK: fptrunc float
; OFF-LABEL: define spir_kernel void @allowed(
; OFF: fptrunc float
; OFF: fpext half

target triple = "spir64"

define spir_kernel void @mixed(float %x, ptr addrspace(1) %out) {
  %h = fptrunc float %x to half
  %f = fpext contract half %h to float
  store float %f, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @mixed_fast(float %x, ptr addrspace(1) %out) {
  %h = fptrunc float %x to half
  %f = fpext fast half %h to float
  store float %f, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @mixed_reassoc(float %x, ptr addrspace(1) %out) {
  %h = fptrunc float %x to half
  %f = fpext reassoc half %h to float
  store float %f, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @allowed(float %x, ptr addrspace(1) %out) {
  %h = fptrunc contract float %x to half
  %f = fpext contract half %h to float
  store float %f, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @strict_division(float %x, float %y, ptr addrspace(1) %out) {
  %v = fdiv float %x, %y
  %h = fptrunc contract float %v to half
  store half %h, ptr addrspace(1) %out
  ret void
}

!spirv.ExecutionMode = !{!0, !1}
!0 = !{ptr @strict_division, i32 6028, half poison, i32 65536}
!1 = !{ptr @strict_division, i32 6028, float poison, i32 65536}
