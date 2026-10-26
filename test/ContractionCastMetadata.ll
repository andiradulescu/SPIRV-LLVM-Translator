; RUN: llvm-spirv %s -o %t.spv
; RUN: spirv-val %t.spv
; RUN: llvm-spirv %s -spirv-text -o - | FileCheck %s
; RUN: llvm-spirv %s --spirv-ext=+SPV_KHR_float_controls2 -o %t.fc2.spv
; RUN: spirv-val %t.fc2.spv
; RUN: llvm-spirv %s --spirv-ext=+SPV_KHR_float_controls2 -spirv-text -o - | FileCheck %s --check-prefix=FC2

; RUN: llvm-spirv -r %t.fc2.spv -o %t.back.bc
; RUN: llvm-spirv %t.back.bc --spirv-ext=+SPV_KHR_float_controls2 -o %t.back.spv
; RUN: spirv-val %t.back.spv
; RUN: llvm-spirv %t.back.bc --spirv-ext=+SPV_KHR_float_controls2 -spirv-text -o - | FileCheck %s --check-prefix=FC2

; Inference must not duplicate an explicit ContractionOff mode.
; CHECK: EntryPoint 6 [[KERNEL:[0-9]+]] "probe"
; CHECK: ExecutionMode [[KERNEL]] 31
; CHECK-NOT: ExecutionMode [[KERNEL]] 31

; Float-controls2 restrictions must be combined per kernel and type, including
; when an explicit default allows contraction. Unrestricted kernels retain
; their explicit defaults.
; FC2-DAG: EntryPoint 6 [[LEGACY:[0-9]+]] "probe"
; FC2-DAG: EntryPoint 6 [[STRICT:[0-9]+]] "strict_defaults"
; FC2-DAG: EntryPoint 6 [[CONTRACT:[0-9]+]] "contract_defaults"
; FC2-DAG: TypeFloat [[HALF:[0-9]+]] 16
; FC2-DAG: TypeFloat [[FLOAT:[0-9]+]] 32
; FC2-DAG: Constant {{[0-9]+}} [[ZERO:[0-9]+]] 0
; FC2-DAG: Constant {{[0-9]+}} [[ALLOW:[0-9]+]] 65536
; FC2-DAG: Constant {{[0-9]+}} [[NOTNAN:[0-9]+]] 1
; FC2-DAG: ExecutionModeId [[LEGACY]] 6028 [[HALF]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[LEGACY]] 6028 [[FLOAT]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[STRICT]] 6028 [[HALF]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[STRICT]] 6028 [[FLOAT]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[CONTRACT]] 6028 [[HALF]] [[ALLOW]]
; FC2-DAG: ExecutionModeId [[CONTRACT]] 6028 [[FLOAT]] [[NOTNAN]]

target triple = "spir64"

define spir_kernel void @probe(float %x, ptr addrspace(1) %out) {
  %h = fptrunc float %x to half
  %f = fpext half %h to float
  store float %f, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @strict_defaults(float %x, ptr addrspace(1) %out) {
  %h = fptrunc float %x to half
  %f = fpext half %h to float
  store float %f, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @contract_defaults(float %x, ptr addrspace(1) %out) {
  %h = fptrunc contract float %x to half
  %f = fpext contract half %h to float
  store float %f, ptr addrspace(1) %out
  ret void
}

!spirv.ExecutionMode = !{!0, !1, !2, !3, !4, !5}
!0 = !{ptr @probe, i32 31}
!1 = !{ptr @strict_defaults, i32 6028, half poison, i32 65536}
!2 = !{ptr @strict_defaults, i32 6028, float poison, i32 0}
!3 = !{ptr @contract_defaults, i32 6028, half poison, i32 65536}
!4 = !{ptr @contract_defaults, i32 6028, float poison, i32 1}
!5 = !{ptr @probe, i32 6028, float poison, i32 65536}
