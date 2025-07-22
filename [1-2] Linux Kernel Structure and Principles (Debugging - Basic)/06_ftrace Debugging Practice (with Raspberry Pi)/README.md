# Ftrace 실습 및 활용 가이드

## 1. Ftrace 기본 제어

### tracing_on 파일
**Ftrace 트레이싱을 시작하거나 중지하는 기본 제어 파일**

#### 기본 사용법
```bash
# 트레이싱 시작
echo 1 > /sys/kernel/debug/tracing/tracing_on

# 트레이싱 중지
echo 0 > /sys/kernel/debug/tracing/tracing_on

# 현재 상태 확인
cat /sys/kernel/debug/tracing/tracing_on
```

#### 중요성
- **마스터 스위치**: 모든 Ftrace 기능의 최상위 제어
- **즉시 적용**: 실시간으로 추적 활성화/비활성화
- **성능 제어**: 필요할 때만 추적하여 시스템 부하 최소화
- **기본 제어**: Ftrace 사용의 첫 번째 단계

#### 실무 활용 패턴
```bash
# 추적 준비
echo 0 > /sys/kernel/debug/tracing/tracing_on  # 우선 중지
echo > /sys/kernel/debug/tracing/trace         # 기존 로그 삭제

# 설정 완료 후 추적 시작
echo 1 > /sys/kernel/debug/tracing/tracing_on

# 분석할 상황 재현
# ... 문제 상황 발생 ...

# 즉시 추적 중지
echo 0 > /sys/kernel/debug/tracing/tracing_on

# 결과 분석
cat /sys/kernel/debug/tracing/trace
```

<br>

## 2. 스케줄링 이벤트 분석

### sched 카테고리
**태스크(프로세스) 스케줄링 활동과 관련된 Ftrace 이벤트 카테고리**

#### 주요 이벤트들
```bash
# sched 카테고리 이벤트 확인
ls /sys/kernel/debug/tracing/events/sched/

# 주요 이벤트들
- sched_switch       # 프로세스 전환
- sched_wakeup       # 프로세스 깨어남
- sched_wakeup_new   # 새 프로세스 깨어남
- sched_migrate_task # 프로세스 CPU 간 이동
- sched_process_fork # 프로세스 생성
- sched_process_exit # 프로세스 종료
```

#### 스케줄링 분석 설정
```bash
# 전체 sched 이벤트 활성화
echo 1 > /sys/kernel/debug/tracing/events/sched/enable

# 특정 이벤트만 활성화
echo 1 > /sys/kernel/debug/tracing/events/sched/sched_switch/enable
echo 1 > /sys/kernel/debug/tracing/events/sched/sched_wakeup/enable

# 특정 프로세스만 추적
echo "comm == firefox" > /sys/kernel/debug/tracing/events/sched/sched_switch/filter
```

#### 실제 분석 예시
```
# sched_switch 출력 예시
systemd-1     [000] .... 12345.678901: sched_switch: prev_comm=systemd prev_pid=1 prev_prio=120 prev_state=S ==> next_comm=kworker/0:1 next_pid=23 next_prio=120

# sched_wakeup 출력 예시  
kworker/0:1-23 [000] .... 12345.678902: sched_wakeup: comm=firefox pid=1234 prio=120 success=1 target_cpu=001
```

<br>

## 3. Function 트레이서

### 함수 실행 흐름 추적
**특정 커널 함수의 진입/종료를 추적하여 실행 흐름을 파악하는 전용 트레이서**

#### 기본 설정
```bash
# function 트레이서 활성화
echo function > /sys/kernel/debug/tracing/current_tracer

# 추적 가능한 함수 목록 확인
cat /sys/kernel/debug/tracing/available_filter_functions | head -20

# 모든 함수 추적 (주의: 높은 오버헤드)
echo > /sys/kernel/debug/tracing/set_ftrace_filter
```

#### 특징
- **함수 진입/종료**: 함수 호출과 반환 지점 추적
- **호출 관계**: 함수 간의 호출 관계 파악
- **실행 흐름**: 커널 코드의 실행 경로 분석
- **성능 분석**: 함수별 실행 빈도 확인

#### Function Graph 트레이서
```bash
# 더 상세한 함수 그래프 추적
echo function_graph > /sys/kernel/debug/tracing/current_tracer

# 실행 시간 표시
echo 1 > /sys/kernel/debug/tracing/options/funcgraph-duration

# 함수 그래프 출력 예시
schedule() {
  __schedule() {
    pick_next_task_fair() {
      load_balance(); /* 1.234 us */
    } /* 5.678 us */
  } /* 10.123 us */
} /* 15.456 us */
```

<br>

## 4. 함수 필터링

### set_ftrace_filter 파일
**Function 트레이서에서 추적할 특정 함수를 지정하는 파일**

#### 기본 사용법
```bash
# 특정 함수만 추적
echo "schedule" > /sys/kernel/debug/tracing/set_ftrace_filter

# 여러 함수 추적
echo "schedule" > /sys/kernel/debug/tracing/set_ftrace_filter
echo "wake_up_process" >> /sys/kernel/debug/tracing/set_ftrace_filter

# 현재 필터 확인
cat /sys/kernel/debug/tracing/set_ftrace_filter
```

#### 고급 필터링 기법
```bash
# 패턴 매칭 사용
echo "*schedule*" > /sys/kernel/debug/tracing/set_ftrace_filter    # schedule 포함 함수들
echo "schedule*" > /sys/kernel/debug/tracing/set_ftrace_filter     # schedule로 시작
echo "*_schedule" > /sys/kernel/debug/tracing/set_ftrace_filter    # schedule로 끝남

# 모듈별 필터링
echo ":mod:ext4" > /sys/kernel/debug/tracing/set_ftrace_filter     # ext4 모듈 함수들

# 함수 제외
echo "!schedule_timeout" > /sys/kernel/debug/tracing/set_ftrace_notrace

# 필터 초기화 (모든 함수)
echo > /sys/kernel/debug/tracing/set_ftrace_filter
```

#### 실무 활용 전략
```bash
# 1단계: 넓은 범위로 시작
echo "*mm*" > /sys/kernel/debug/tracing/set_ftrace_filter

# 2단계: 관심 영역 축소
echo "alloc_pages*" > /sys/kernel/debug/tracing/set_ftrace_filter
echo "free_pages*" >> /sys/kernel/debug/tracing/set_ftrace_filter

# 3단계: 특정 함수에 집중
echo "alloc_pages_vma" > /sys/kernel/debug/tracing/set_ftrace_filter
```

<br>

## 5. 호출 스택 분석

### 호출 스택 정보의 활용
**특정 이벤트나 함수 호출이 발생한 전체 경로 이해**

#### 주요 이점
- **근본 원인 파악**: 문제가 발생한 정확한 호출 경로 추적
- **실행 흐름 이해**: 복잡한 커널 코드의 실행 순서 파악
- **성능 병목 발견**: 어떤 함수에서 시간이 많이 소모되는지 확인
- **코드 학습**: 커널 내부 동작 원리 이해

#### 스택 추적 활성화
```bash
# Function 트레이서에서 스택 추적 활성화
echo 1 > /sys/kernel/debug/tracing/options/func_stack_trace

# 특정 함수에서만 스택 추적
echo "schedule" > /sys/kernel/debug/tracing/set_ftrace_filter
echo 1 > /sys/kernel/debug/tracing/options/func_stack_trace
```

#### 스택 추적 출력 예시
```
systemd-1     [000] .... 12345.678901: schedule <-schedule_timeout
systemd-1     [000] .... 12345.678901: <stack trace>
 => schedule_timeout
 => wait_for_completion_timeout
 => flush_work
 => cancel_work_sync
 => cleanup_module
```

#### 분석 방법
```bash
# 1. 호출 스택이 포함된 로그 수집
echo function > /sys/kernel/debug/tracing/current_tracer
echo "target_function" > /sys/kernel/debug/tracing/set_ftrace_filter
echo 1 > /sys/kernel/debug/tracing/options/func_stack_trace
echo 1 > /sys/kernel/debug/tracing/tracing_on

# 2. 문제 상황 재현
# ... 문제 발생 ...

# 3. 즉시 추적 중지
echo 0 > /sys/kernel/debug/tracing/tracing_on

# 4. 스택 추적 분석
grep -A 10 "target_function" /sys/kernel/debug/tracing/trace
```

<br>

## 6. 종합 실습 예시

### 성능 문제 분석 시나리오
```bash
#!/bin/bash
# 시스템 성능 저하 분석 스크립트

echo "=== Ftrace 성능 분석 시작 ==="

# 1. 초기화
echo 0 > /sys/kernel/debug/tracing/tracing_on
echo > /sys/kernel/debug/tracing/trace

# 2. 스케줄링 분석 설정
echo 1 > /sys/kernel/debug/tracing/events/sched/sched_switch/enable
echo 1 > /sys/kernel/debug/tracing/events/sched/sched_wakeup/enable

# 3. 메모리 관련 함수 추적
echo function > /sys/kernel/debug/tracing/current_tracer
echo "alloc_pages*" > /sys/kernel/debug/tracing/set_ftrace_filter
echo "free_pages*" >> /sys/kernel/debug/tracing/set_ftrace_filter

# 4. 추적 시작
echo 1 > /sys/kernel/debug/tracing/tracing_on

echo "문제 상황을 재현하세요. 완료되면 Enter를 누르세요."
read

# 5. 추적 중지
echo 0 > /sys/kernel/debug/tracing/tracing_on

# 6. 결과 저장
cp /sys/kernel/debug/tracing/trace /tmp/ftrace_analysis.log
echo "분석 결과가 /tmp/ftrace_analysis.log에 저장되었습니다."

# 7. 기본 분석
echo "=== 기본 통계 ==="
echo "컨텍스트 스위치 횟수: $(grep sched_switch /tmp/ftrace_analysis.log | wc -l)"
echo "메모리 할당 횟수: $(grep alloc_pages /tmp/ftrace_analysis.log | wc -l)"
echo "메모리 해제 횟수: $(grep free_pages /tmp/ftrace_analysis.log | wc -l)"
```

### 인터럽트 분석 예시
```bash
# 인터럽트 처리 분석
echo 1 > /sys/kernel/debug/tracing/events/irq/enable
echo function_graph > /sys/kernel/debug/tracing/current_tracer
echo "*irq*" > /sys/kernel/debug/tracing/set_ftrace_filter
echo 1 > /sys/kernel/debug/tracing/options/funcgraph-duration
```

<br>

## 핵심 요점

1. **tracing_on**: Ftrace의 마스터 스위치, 모든 추적의 시작점
2. **sched 카테고리**: 스케줄링 관련 모든 이벤트의 중심
3. **function 트레이서**: 함수 실행 흐름 추적의 핵심 도구
4. **set_ftrace_filter**: 추적 범위를 제한하여 효율적인 분석 가능
5. **호출 스택 분석**: 문제의 근본 원인과 실행 경로 파악의 열쇠

Ftrace는 단계적 접근과 적절한 필터링을 통해 복잡한 커널 문제도 체계적으로 분석할 수 있는 강력한 도구입니다.