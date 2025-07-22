#!/bin/bash

# Ftrace 중지
echo 0 > /sys/kernel/debug/tracing/tracing_on   
sleep 1
echo "tracing_off"

echo 0 > /sys/kernel/debug/tracing/events/enable
sleep 1
echo "events disabled"

# 더미로 임시 필터 설정 (락업 상태 방지)
echo secondary_start_kernel > /sys/kernel/debug/tracing/set_ftrace_filter
sleep 1
echo "set_ftrace_filter_init"

# Function tracer 활성화
echo function > /sys/kernel/debug/tracing/current_tracer  
sleep 1
echo "function tracer enabled"

# 이벤트 활성화
# 스케줄링 이벤트
echo 1 > /sys/kernel/debug/tracing/events/sched/sched_wakeup/enable
echo 1 > /sys/kernel/debug/tracing/events/sched/sched_switch/enable

# 인터럽트 이벤트
echo 1 > /sys/kernel/debug/tracing/events/irq/irq_handler_entry/enable
echo 1 > /sys/kernel/debug/tracing/events/irq/irq_handler_exit/enable

# 시스템 콜 이벤트
echo 1 > /sys/kernel/debug/tracing/events/raw_syscalls/enable
sleep 1
echo "event enabled"

# 추적할 함수 지정
echo schedule ttwu_do_wakeup > /sys/kernel/debug/tracing/set_ftrace_filter
sleep 1
echo "set_ftrace_filter enabled"

# 스택 추적 활성화
echo 1 > /sys/kernel/debug/tracing/options/func_stack_trace
# 심볼 오프셋 표시
echo 1 > /sys/kernel/debug/tracing/options/sym-offset
echo "function stack trace enabled"

# 추적 시작
echo 1 > /sys/kernel/debug/tracing/tracing_on
echo "tracing_on"