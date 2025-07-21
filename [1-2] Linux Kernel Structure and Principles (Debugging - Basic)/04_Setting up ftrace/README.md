# 리눅스 Ftrace 디버깅 완전 가이드

## 1. Ftrace 개요

### 주요 목적
**커널 내부 동작 학습 및 성능 디버깅**

#### 핵심 기능
- **커널 동작 파악**: 리눅스 커널의 상세한 내부 동작 분석
- **성능 디버깅**: 시스템 성능 문제 진단 및 최적화
- **실시간 추적**: 커널 실행 중 동적 모니터링
- **비침습적 분석**: 소스 코드 수정 없이 분석 가능

#### 활용 분야
- 커널 개발 및 학습
- 시스템 성능 분석
- 버그 추적 및 디버깅
- 시스템 동작 이해

<br>

## 2. Ftrace 제어 시스템

### 전역 제어 파일
**tracing_on**

#### 기본 사용법
```bash
# Ftrace 활성화
echo 1 > /sys/kernel/debug/tracing/tracing_on

# Ftrace 비활성화
echo 0 > /sys/kernel/debug/tracing/tracing_on

# 현재 상태 확인
cat /sys/kernel/debug/tracing/tracing_on
```

#### 중요성
- **전역 스위치**: 모든 Ftrace 기능의 마스터 제어
- **즉시 적용**: 실시간으로 추적 활성화/비활성화
- **성능 제어**: 필요시에만 추적하여 시스템 부하 최소화

### 기타 주요 제어 파일
```bash
# 트레이서 선택
echo function > /sys/kernel/debug/tracing/current_tracer

# 버퍼 크기 설정
echo 1024 > /sys/kernel/debug/tracing/buffer_size_kb

# 추적 결과 확인
cat /sys/kernel/debug/tracing/trace
```

<br>

## 3. 트레이서 유형

### NOP Tracer (기본 트레이서)
**Ftrace가 특정 설정 없이 기본적으로 활성화될 때 사용되는 트레이서**

#### 특징
- **기본 상태**: Ftrace의 기본 트레이서
- **이벤트 중심**: 주로 트레이스 포인트 이벤트 포착
- **가벼운 오버헤드**: 최소한의 시스템 부하
- **이벤트 기반**: 함수 호출보다는 특정 이벤트에 집중

#### 사용 방법
```bash
# NOP 트레이서 설정 (기본값)
echo nop > /sys/kernel/debug/tracing/current_tracer

# 이벤트 활성화
echo 1 > /sys/kernel/debug/tracing/events/syscalls/sys_enter_open/enable
```

### Function Tracer
**함수 호출 추적에 특화된 트레이서**

#### 특징
- **함수 추적**: 커널 함수 호출 및 반환 추적
- **상세한 정보**: 함수 실행 시간 및 호출 관계
- **높은 오버헤드**: 상세한 정보 수집으로 인한 성능 영향

#### 사용 방법
```bash
# Function 트레이서 설정
echo function > /sys/kernel/debug/tracing/current_tracer

# 모든 함수 추적 (주의: 높은 오버헤드)
echo > /sys/kernel/debug/tracing/set_ftrace_filter
```

<br>

## 4. 함수 필터링

### set_ftrace_filter 파일
**Function Tracer에서 추적할 함수들을 지정하는 파일**

#### 목적
- **선택적 추적**: 특정 함수만 추적하여 오버헤드 감소
- **집중 분석**: 관심 있는 함수에만 집중
- **로그 관리**: 과도한 로그 생성 방지

#### 사용 예시
```bash
# 특정 함수만 추적
echo "schedule" > /sys/kernel/debug/tracing/set_ftrace_filter

# 여러 함수 추적
echo "schedule" > /sys/kernel/debug/tracing/set_ftrace_filter
echo "wake_up_process" >> /sys/kernel/debug/tracing/set_ftrace_filter

# 패턴 매칭 사용
echo "*schedule*" > /sys/kernel/debug/tracing/set_ftrace_filter

# 필터 확인
cat /sys/kernel/debug/tracing/set_ftrace_filter

# 필터 초기화 (모든 함수 추적)
echo > /sys/kernel/debug/tracing/set_ftrace_filter
```

#### 고급 필터링
```bash
# 특정 모듈의 함수만 추적
echo ":mod:ext4" > /sys/kernel/debug/tracing/set_ftrace_filter

# 함수 제외 (notrace)
echo "!schedule" > /sys/kernel/debug/tracing/set_ftrace_notrace
```

<br>

## 5. 트레이스 포인트 (Trace Points)

### 정의
**리눅스 커널 내의 특정 계측 지점**

#### 특징
- **명시적 삽입**: 커널 코드 내에 미리 정의된 계측 지점
- **이벤트 기반**: 특정 이벤트 발생 시 정보 수집
- **효율적**: 함수 추적보다 낮은 오버헤드
- **구조화된 정보**: 이벤트별로 정의된 구조화된 데이터

#### 주요 카테고리
```bash
# 사용 가능한 이벤트 확인
ls /sys/kernel/debug/tracing/events/

# 주요 이벤트 카테고리
- syscalls/     # 시스템 콜 이벤트
- sched/        # 스케줄링 이벤트
- irq/          # 인터럽트 이벤트
- kmem/         # 메모리 관리 이벤트
- block/        # 블록 I/O 이벤트
- net/          # 네트워크 이벤트
```

#### 이벤트 활성화
```bash
# 특정 이벤트 활성화
echo 1 > /sys/kernel/debug/tracing/events/syscalls/sys_enter_open/enable

# 카테고리 전체 활성화
echo 1 > /sys/kernel/debug/tracing/events/sched/enable

# 모든 이벤트 활성화 (주의: 높은 오버헤드)
echo 1 > /sys/kernel/debug/tracing/events/enable
```

<br>

## 6. 실무 활용 예시

### 시스템 콜 추적
```bash
#!/bin/bash
# 시스템 콜 추적 스크립트

# Ftrace 초기화
echo 0 > /sys/kernel/debug/tracing/tracing_on
echo nop > /sys/kernel/debug/tracing/current_tracer
echo > /sys/kernel/debug/tracing/trace

# 시스템 콜 이벤트 활성화
echo 1 > /sys/kernel/debug/tracing/events/syscalls/enable

# 추적 시작
echo 1 > /sys/kernel/debug/tracing/tracing_on

echo "Tracing system calls... Press Enter to stop"
read

# 추적 중지
echo 0 > /sys/kernel/debug/tracing/tracing_on

# 결과 확인
echo "=== Trace Results ==="
cat /sys/kernel/debug/tracing/trace
```

### 스케줄링 분석
```bash
#!/bin/bash
# 스케줄링 동작 분석

# Function tracer 설정
echo function > /sys/kernel/debug/tracing/current_tracer
echo "schedule*" > /sys/kernel/debug/tracing/set_ftrace_filter

# 스케줄링 이벤트 활성화
echo 1 > /sys/kernel/debug/tracing/events/sched/sched_switch/enable
echo 1 > /sys/kernel/debug/tracing/events/sched/sched_wakeup/enable

# 추적 시작
echo 1 > /sys/kernel/debug/tracing/tracing_on
```

### 성능 분석
```bash
#!/bin/bash
# 특정 함수의 성능 분석

# Function graph tracer 사용
echo function_graph > /sys/kernel/debug/tracing/current_tracer
echo "target_function" > /sys/kernel/debug/tracing/set_graph_function

# 실행 시간 측정 활성화
echo 1 > /sys/kernel/debug/tracing/options/funcgraph-duration

# 추적 시작
echo 1 > /sys/kernel/debug/tracing/tracing_on
```

<br>

## 7. 추적 결과 분석

### 기본 로그 형식
```
# tracer: function
#
# entries-in-buffer/entries-written: 140/140   #P:4
#
#                              _-----=> irqs-off
#                             / _----=> need-resched
#                            | / _---=> hardirq/softirq
#                            || / _--=> preempt-depth
#                            ||| /     delay
#           TASK-PID   CPU#  ||||    TIMESTAMP  FUNCTION
#              | |       |   ||||       |         |
           <...>-1234  [001] .... 12345.678901: schedule <-schedule_timeout
```

### 주요 필드 설명
- **TASK-PID**: 프로세스 이름과 PID
- **CPU#**: 실행 중인 CPU 번호
- **TIMESTAMP**: 이벤트 발생 시간
- **FUNCTION**: 호출된 함수 또는 이벤트

<br>

## 8. 성능 고려사항

### 오버헤드 최소화 전략
1. **선택적 추적**: 필요한 함수/이벤트만 활성화
2. **버퍼 크기 조정**: 적절한 버퍼 크기 설정
3. **필터 활용**: set_ftrace_filter로 범위 제한
4. **일시적 사용**: 분석 완료 후 즉시 비활성화

### 권장 사용 패턴
```bash
# 1. 최소한의 설정으로 시작
echo nop > /sys/kernel/debug/tracing/current_tracer
echo 1 > /sys/kernel/debug/tracing/events/specific_event/enable

# 2. 문제 재현
# 실제 문제 상황 재현

# 3. 즉시 비활성화
echo 0 > /sys/kernel/debug/tracing/tracing_on

# 4. 결과 분석
cat /sys/kernel/debug/tracing/trace > analysis.log
```

<br>

## 핵심 요점

1. **Ftrace**: 커널 학습과 성능 디버깅의 핵심 도구
2. **tracing_on**: 전역 제어를 위한 마스터 스위치
3. **NOP Tracer**: 기본 트레이서, 이벤트 중심 추적
4. **set_ftrace_filter**: 함수 필터링으로 오버헤드 제어
5. **Trace Points**: 효율적인 이벤트 기반 계측 지점

Ftrace는 강력하지만 올바른 사용법을 익혀야 시스템에 부담 없이 효과적인 디버깅이 가능합니다.