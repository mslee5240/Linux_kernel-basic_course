# Ftrace 메시지 분석 및 해석 가이드

## 1. Ftrace 메시지 기본 구조

### 메시지 형식 개요
```
TASK-PID   CPU#  FLAGS  TIMESTAMP: FUNCTION
  |  |      |      |        |         |
  |  |      |      |        |         +-- 함수/이벤트 정보
  |  |      |      |        +------------ 타임스탬프
  |  |      |      +-------------------- 컨텍스트 플래그
  |  |      +--------------------------- CPU 번호
  |  +---------------------------------- 프로세스 ID
  +------------------------------------- 프로세스 이름
```

### 가장 왼쪽 정보: 프로세스 식별
**프로세스 이름과 PID**

#### 표시 형식
```
<TASK_NAME>-<PID>
```

#### 예시
```
systemd-1
kworker/0:1-23
firefox-1234
<idle>-0
```

#### 중요성
- **프로세스 추적**: 어떤 프로세스의 활동인지 즉시 파악
- **문제 격리**: 특정 프로세스 관련 이슈 식별
- **시스템 동작 이해**: 프로세스별 커널 사용 패턴 분석

<br>

## 2. 컨텍스트 정보 (FLAGS)

### 컨텍스트 플래그 해석
**시스템 실행 상태를 나타내는 중요한 정보**

#### 주요 플래그 종류
| 플래그 | 의미 | 설명 |
|--------|------|------|
| **H** | 인터럽트 핸들러 컨텍스트 | 인터럽트 처리 중 |
| **S** | 소프트 인터럽트 컨텍스트 | 소프트IRQ 처리 중 |
| **d** | 인터럽트 비활성화 | IRQ 비활성화 상태 |
| **N** | Need Resched | 스케줄링 필요 |
| **P** | 선점 불가 | 선점 비활성화 상태 |

#### 인터럽트 핸들러 컨텍스트 ('H')
```
kworker/0:1-23  [000] ..H. 12345.678901: irq_handler_entry
```

**특징:**
- **실행 컨텍스트**: 하드웨어 인터럽트 처리 중
- **제약사항**: 슬립 함수 사용 불가
- **성능 영향**: 시스템 응답성에 직접적 영향
- **분석 용도**: 인터럽트 처리 성능 및 빈도 분석

#### 컨텍스트 조합 예시
```
[000] .N..  # CPU 0, Need Resched 플래그
[001] d...  # CPU 1, 인터럽트 비활성화
[002] ..H.  # CPU 2, 인터럽트 핸들러 컨텍스트
[003] ...S  # CPU 3, 소프트 인터럽트 컨텍스트
```

<br>

## 3. 스케줄링 추적

### sched_switch 이벤트
**태스크 스케줄링 동작을 추적하는 핵심 이벤트**

#### 이벤트 형식
```
prev_comm=TASK prev_pid=PID prev_prio=PRIO prev_state=STATE ==> next_comm=TASK next_pid=PID next_prio=PRIO
```

#### 실제 예시
```
systemd-1     [000] .... 12345.678901: sched_switch: prev_comm=systemd prev_pid=1 prev_prio=120 prev_state=S ==> next_comm=kworker/0:1 next_pid=23 next_prio=120
```

#### 정보 해석
- **prev_comm/next_comm**: 이전/다음 프로세스 이름
- **prev_pid/next_pid**: 이전/다음 프로세스 ID
- **prev_prio/next_prio**: 우선순위 (낮을수록 높은 우선순위)
- **prev_state**: 이전 프로세스 상태
  - `R`: Running (실행 중)
  - `S`: Sleeping (대기)
  - `D`: Uninterruptible sleep (중단 불가능한 대기)
  - `Z`: Zombie (좀비)

#### 활용 방법
```bash
# sched_switch 이벤트 활성화
echo 1 > /sys/kernel/debug/tracing/events/sched/sched_switch/enable

# 특정 프로세스만 추적
echo "comm == firefox" > /sys/kernel/debug/tracing/events/sched/sched_switch/filter
```

<br>

## 4. Function Tracer 분석

### 함수 호출 스택 정보
**Function Tracer로 확인할 수 있는 핵심 정보**

#### 기본 함수 추적
```
systemd-1     [000] .... 12345.678901: schedule <-schedule_timeout
systemd-1     [000] .... 12345.678902: __schedule <-schedule
systemd-1     [000] .... 12345.678903: pick_next_task_fair <-__schedule
```

#### Function Graph Tracer
```
systemd-1     [000] .... 12345.678901: schedule() {
systemd-1     [000] .... 12345.678902:   __schedule() {
systemd-1     [000] .... 12345.678903:     pick_next_task_fair() {
systemd-1     [000] .... 12345.678904:       load_balance();
systemd-1     [000] .... 12345.678905:     } /* pick_next_task_fair */
systemd-1     [000] .... 12345.678906:   } /* __schedule */
systemd-1     [000] .... 12345.678907: } /* schedule */
```

#### 활용 목적
- **실행 흐름 파악**: 커널 함수 호출 순서 이해
- **성능 분석**: 함수별 실행 시간 측정
- **버그 추적**: 예상과 다른 실행 경로 발견
- **학습 도구**: 커널 내부 동작 원리 학습

<br>

## 5. 이벤트-코드 연관성

### trace_ 접두사 규칙
**Ftrace 이벤트와 커널 함수의 연관성**

#### 명명 규칙
```c
// 커널 코드에서 이벤트 호출
trace_sched_switch(prev, next);
trace_irq_handler_entry(irq, action);
trace_mm_page_alloc(page, order, gfp_flags, migratetype);
```

#### 이벤트 이름과 함수 매핑
| 이벤트 이름 | 커널 함수 | 설명 |
|------------|-----------|------|
| `sched_switch` | `trace_sched_switch()` | 프로세스 전환 |
| `irq_handler_entry` | `trace_irq_handler_entry()` | 인터럽트 진입 |
| `mm_page_alloc` | `trace_mm_page_alloc()` | 페이지 할당 |
| `sys_enter_open` | `trace_sys_enter()` | 시스템 콜 진입 |

#### 코드 추적 방법
```bash
# 특정 이벤트 위치 찾기
grep -r "trace_sched_switch" /usr/src/linux/

# 이벤트 정의 확인
cat /sys/kernel/debug/tracing/events/sched/sched_switch/format
```

<br>

## 6. 실무 분석 예시

### 성능 문제 분석
```bash
# 스케줄링 지연 분석
echo 1 > /sys/kernel/debug/tracing/events/sched/sched_switch/enable
echo 1 > /sys/kernel/debug/tracing/events/sched/sched_wakeup/enable

# 분석할 프로세스 필터링
echo "next_comm == target_process" > /sys/kernel/debug/tracing/events/sched/sched_switch/filter
```

### 인터럽트 분석
```bash
# 인터럽트 처리 시간 분석
echo function_graph > /sys/kernel/debug/tracing/current_tracer
echo "*irq*" > /sys/kernel/debug/tracing/set_ftrace_filter
echo 1 > /sys/kernel/debug/tracing/options/funcgraph-duration
```

### 시스템 콜 추적
```bash
# 파일 시스템 관련 시스템 콜 추적
echo 1 > /sys/kernel/debug/tracing/events/syscalls/sys_enter_open/enable
echo 1 > /sys/kernel/debug/tracing/events/syscalls/sys_enter_read/enable
echo 1 > /sys/kernel/debug/tracing/events/syscalls/sys_enter_write/enable
```

<br>

## 7. 메시지 해석 실습

### 종합 분석 예시
```
# 예시 Ftrace 출력
firefox-1234  [001] d.h. 12345.678901: irq_handler_entry: irq=23 name=ehci_hcd:usb1
firefox-1234  [001] d.h. 12345.678902: irq_handler_exit: irq=23 ret=handled
firefox-1234  [001] d... 12345.678903: sched_switch: prev_comm=firefox prev_pid=1234 prev_prio=120 prev_state=R ==> next_comm=kworker/1:1 next_pid=45 next_prio=120
```

#### 해석
1. **프로세스**: firefox (PID 1234)가 CPU 1에서 실행 중
2. **컨텍스트**: 인터럽트 비활성화 상태에서 하드웨어 인터럽트 처리
3. **이벤트**: USB 컨트롤러 인터럽트 처리 후 프로세스 전환
4. **스케줄링**: firefox에서 kworker로 컨텍스트 스위치

<br>

## 8. 분석 도구 및 팁

### 효율적인 분석 방법
```bash
# 시간 범위 필터링
echo "common_timestamp > 12345.678000 && common_timestamp < 12345.679000" > /sys/kernel/debug/tracing/events/filter

# CPU별 분석
cat /sys/kernel/debug/tracing/per_cpu/cpu0/trace

# 실시간 모니터링
tail -f /sys/kernel/debug/tracing/trace_pipe
```

### 분석 스크립트 예시
```bash
#!/bin/bash
# Ftrace 로그 자동 분석 스크립트

# 주요 메트릭 추출
grep "sched_switch" /tmp/trace.log | wc -l  # 컨텍스트 스위치 횟수
grep "irq_handler_entry" /tmp/trace.log | awk '{print $NF}' | sort | uniq -c  # 인터럽트 빈도
grep "..H." /tmp/trace.log | wc -l  # 인터럽트 핸들러 실행 횟수
```

<br>

## 핵심 요점

1. **프로세스 식별**: 메시지 왼쪽의 프로세스 이름과 PID로 활동 주체 파악
2. **컨텍스트 정보**: 'H' 플래그 등으로 시스템 실행 상태 이해
3. **sched_switch**: 스케줄링 동작 추적의 핵심 이벤트
4. **함수 호출 스택**: Function Tracer로 커널 실행 흐름 분석
5. **trace_ 접두사**: 이벤트와 커널 코드의 연관성 파악

Ftrace 메시지를 체계적으로 해석할 수 있으면 복잡한 커널 동작도 명확하게 이해할 수 있습니다.