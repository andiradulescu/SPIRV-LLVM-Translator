; RUN: llvm-as %s -o %t.bc
; RUN: llvm-spirv %t.bc -o %t.spv
; RUN: llvm-spirv %t.spv -to-text -o %t.spt
; RUN: FileCheck %s --input-file=%t.spt --check-prefixes=ENTRY,LEGACY --implicit-check-not=ExecutionModeId --implicit-check-not=FPFastMathMode
; RUN: FileCheck %s --input-file=%t.spt --check-prefix=ALLOW
; RUN: spirv-val %t.spv
; RUN: llvm-spirv %t.bc -o %t.on.spv --spirv-fp-contract=on
; RUN: llvm-spirv %t.on.spv -to-text -o - | FileCheck %s --check-prefixes=ENTRY,LEGACY
; RUN: spirv-val %t.on.spv
; RUN: llvm-spirv %t.bc -o %t.off.spv --spirv-fp-contract=off
; RUN: llvm-spirv %t.off.spv -to-text -o - | FileCheck %s --check-prefixes=ENTRY,LEGACY,OFF
; RUN: spirv-val %t.off.spv
; RUN: llvm-spirv %t.bc -o %t.fast.spv --spirv-fp-contract=fast
; RUN: llvm-spirv %t.fast.spv -to-text -o - | FileCheck %s --check-prefix=FAST
; RUN: spirv-val %t.fast.spv
; RUN: llvm-spirv %t.bc -o %t.fc2.spv --spirv-ext=+SPV_KHR_float_controls2
; RUN: llvm-spirv %t.bc -spirv-text --spirv-ext=+SPV_KHR_float_controls2 -o %t.fc2.spt
; RUN: FileCheck %s --input-file=%t.fc2.spt --check-prefixes=ENTRY,FC2 --implicit-check-not='ExecutionMode {{[0-9]+}} 31'
; RUN: FileCheck %s --input-file=%t.fc2.spt --check-prefix=ALLOW
; RUN: spirv-val %t.fc2.spv
; RUN: llvm-spirv -r %t.fc2.spv -o %t.roundtrip.bc
; RUN: llvm-spirv %t.roundtrip.bc --spirv-ext=+SPV_KHR_float_controls2 -o %t.roundtrip.spv
; RUN: spirv-val %t.roundtrip.spv
; RUN: llvm-spirv %t.roundtrip.bc --spirv-ext=+SPV_KHR_float_controls2 -spirv-text -o - | FileCheck %s --check-prefixes=ENTRY,FC2
; RUN: llvm-spirv %t.roundtrip.bc --spirv-ext=+SPV_KHR_float_controls2 -spirv-text -o - | FileCheck %s --check-prefix=ALLOW
; RUN: llvm-spirv %t.bc -o %t.fc2.off.spv --spirv-ext=+SPV_KHR_float_controls2 --spirv-fp-contract=off
; RUN: llvm-spirv %t.bc -spirv-text --spirv-ext=+SPV_KHR_float_controls2 --spirv-fp-contract=off -o - | FileCheck %s --check-prefixes=ENTRY,FC2,FC2-OFF
; RUN: spirv-val %t.fc2.off.spv
; RUN: llvm-spirv %t.bc -o %t.fc2.fast.spv --spirv-ext=+SPV_KHR_float_controls2 --spirv-fp-contract=fast
; RUN: llvm-spirv %t.fc2.fast.spv -to-text -o - | FileCheck %s --check-prefix=FAST
; RUN: spirv-val %t.fc2.fast.spv

; Casts without contract flags must preserve intermediate rounding.
; ENTRY-DAG: EntryPoint 6 [[STRICT:[0-9]+]] "strict"
; ENTRY-DAG: EntryPoint 6 [[VECTOR:[0-9]+]] "vector"
; ENTRY-DAG: EntryPoint 6 [[NARROW:[0-9]+]] "strict_narrow"
; ENTRY-DAG: EntryPoint 6 [[WIDE:[0-9]+]] "strict_wide"
; ENTRY-DAG: EntryPoint 6 [[CALLED:[0-9]+]] "called"
; ENTRY-DAG: EntryPoint 6 [[CONTRACT:[0-9]+]] "contract"
; LEGACY-DAG: ExecutionMode [[STRICT]] 31
; LEGACY-DAG: ExecutionMode [[VECTOR]] 31
; LEGACY-DAG: ExecutionMode [[NARROW]] 31
; LEGACY-DAG: ExecutionMode [[WIDE]] 31
; LEGACY-DAG: ExecutionMode [[CALLED]] 31
; OFF-DAG: ExecutionMode [[CONTRACT]] 31

; With float-controls2, the same restriction uses FPFastMathDefault instead.
; FC2-DAG: TypeFloat [[HALF:[0-9]+]] 16
; FC2-DAG: TypeFloat [[FLOAT:[0-9]+]] 32
; FC2-DAG: Constant {{[0-9]+}} [[ZERO:[0-9]+]] 0
; FC2-DAG: ExecutionModeId [[STRICT]] 6028 [[HALF]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[STRICT]] 6028 [[FLOAT]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[VECTOR]] 6028 [[HALF]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[VECTOR]] 6028 [[FLOAT]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[NARROW]] 6028 [[HALF]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[NARROW]] 6028 [[FLOAT]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[WIDE]] 6028 [[HALF]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[WIDE]] 6028 [[FLOAT]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[CALLED]] 6028 [[HALF]] [[ZERO]]
; FC2-DAG: ExecutionModeId [[CALLED]] 6028 [[FLOAT]] [[ZERO]]
; FC2-OFF-DAG: ExecutionModeId [[CONTRACT]] 6028 [[HALF]] [[ZERO]]
; FC2-OFF-DAG: ExecutionModeId [[CONTRACT]] 6028 [[FLOAT]] [[ZERO]]

; Check the entire execution-mode section for the all-contract control.
; ALLOW: EntryPoint 6 [[CONTRACT:[0-9]+]] "contract"
; ALLOW-NOT: ExecutionMode{{(Id)?}} [[CONTRACT]] {{(31|6028)}}
; FAST-NOT: ExecutionMode

target triple = "spir64"

define spir_kernel void @strict(float %x, ptr addrspace(1) %out) {
  %h = fptrunc float %x to half
  %f = fpext half %h to float
  store float %f, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @vector(<4 x float> %x, ptr addrspace(1) %out) {
  %h = fptrunc <4 x float> %x to <4 x half>
  %f = fpext <4 x half> %h to <4 x float>
  store <4 x float> %f, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @strict_narrow(float %x, ptr addrspace(1) %out) {
  %h = fptrunc float %x to half
  %f = fpext contract half %h to float
  store float %f, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @strict_wide(float %x, ptr addrspace(1) %out) {
  %h = fptrunc contract float %x to half
  %f = fpext half %h to float
  store float %f, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @called(float %x, ptr addrspace(1) %out) {
  %f = call spir_func float @roundtrip(float %x)
  store float %f, ptr addrspace(1) %out
  ret void
}

define spir_kernel void @contract(float %x, ptr addrspace(1) %out) {
  %h = fptrunc contract float %x to half
  %f = fpext contract half %h to float
  store float %f, ptr addrspace(1) %out
  ret void
}

define spir_func float @roundtrip(float %x) {
  %h = fptrunc float %x to half
  %f = fpext half %h to float
  ret float %f
}
