# 리눅스 커널 고급 디버깅 기법 - dump_stack()과 SysRq 매직 키

## 1. dump_stack() 함수

### 주요 역할
**콜 스택 정보 출력**

#### 기본 기능
- **함수 호출 경로**: 코드 실행 시의 함수 호출 순서 추적
- **콜 스택 출력**: 현재 실행 지점까지의 전체 호출 스택 표시
- **커널 로그**: 스택 정보를 커널 로그로 출력

#### 활용 목적
- 코드 실행 흐름 분석
- 함수 호출 관계 파악
- 디버깅 시 실행 경로 추적
- 예상치 못한 코드 실행 경로 발견

### 사용 예시
```c
void some_function(void)
{
    // 현재 지점의 콜 스택 출력
    dump_stack();
    
    // 다른 코드들...
}
```

<br>

## 2. dump_stack() 사용 시 주의사항

### 성능 영향
**시스템 응답 속도 저하**

#### 문제 원인
- **높은 오버헤드**: 많은 내부 작업 수행
- **빈번한 호출**: 코드 실행 경로에 너무 자주 추가
- **시스템 부하**: 전체 시스템 성능에 심각한 영향

#### 발생 가능한 문제
- **응답 지연**: 시스템 전반적인 반응 속도 저하
- **로그 과부하**: 대량의 스택 정보로 인한 로그 시스템 부담
- **실시간 처리 영향**: 타이밍이 중요한 작업에 악영향

#### 권장 사용법
- **선택적 사용**: 꼭 필요한 지점에만 배치
- **조건부 실행**: 디버그 모드에서만 활성화
- **임시 사용**: 문제 해결 후 제거

```c
#ifdef DEBUG_STACK
    dump_stack();
#endif
```

<br>

## 3. 대안 디버깅 도구

### ftrace를 통한 콜 스택 분석
**런타임에 커널 소스 코드 수정 없이 콜 스택 분석 가능**

#### ftrace의 장점
- **비침습적**: 소스 코드 수정 불필요
- **런타임 제어**: 실행 중 동적으로 활성화/비활성화
- **성능 효율**: dump_stack()보다 낮은 오버헤드
- **상세 분석**: 함수 호출 시간 및 빈도 분석 가능

#### 사용 방법
```bash
# function tracer 활성화
echo function > /sys/kernel/debug/tracing/current_tracer

# 특정 함수만 추적
echo "target_function" > /sys/kernel/debug/tracing/set_ftrace_filter

# 스택 추적 활성화
echo 1 > /sys/kernel/debug/tracing/options/func_stack_trace
```

<br>

## 4. SysRq 매직 키

### 주요 목적
**커널 디버깅 및 시스템 정보 출력**

#### 핵심 기능
- **시스템 강제 제어**: 시스템이 멈췄을 때 강제로 정보 수집
- **비정상 상태 복구**: 시스템 정지 상황에서 디버깅 정보 획득
- **커널 핵심 기능**: 하드웨어 수준의 직접적인 시스템 접근

#### 활용 상황
- **시스템 정지**: 완전히 멈춘 시스템에서 정보 수집
- **응답 없음**: GUI나 터미널이 응답하지 않을 때
- **커널 패닉**: 심각한 커널 오류 발생 시
- **디버깅**: 시스템 상태 분석이 필요할 때

<br>

## 5. SysRq 매직 키 사용법

### 기본 사용 방법
**echo <key> > /proc/sysrq-trigger**

#### 주요 명령어들
```bash
# 모든 프로세스 정보 출력
echo t > /proc/sysrq-trigger

# 메모리 정보 출력
echo m > /proc/sysrq-trigger

# CPU 정보 및 레지스터 상태
echo p > /proc/sysrq-trigger

# 모든 작업 큐 정보
echo q > /proc/sysrq-trigger

# 시스템 강제 재부팅
echo b > /proc/sysrq-trigger

# 도움말 출력
echo h > /proc/sysrq-trigger
```

### 키보드를 통한 사용
```
Alt + SysRq + <command key>
```

### SysRq 활성화 확인
```bash
# SysRq 상태 확인
cat /proc/sys/kernel/sysrq

# SysRq 활성화 (모든 기능)
echo 1 > /proc/sys/kernel/sysrq
```

<br>

## 6. 주요 SysRq 명령어 상세

| 키 | 기능 | 설명 |
|---|-----|------|
| h | Help | 사용 가능한 명령어 목록 출력 |
| t | Task | 모든 프로세스의 상태 정보 출력 |
| m | Memory | 메모리 사용량 정보 출력 |
| p | CPU | 현재 CPU 레지스터 상태 출력 |
| q | Queue | 타이머, 워크큐 정보 출력 |
| w | Blocked | 블로킹된 프로세스 정보 출력 |
| l | Backtrace | 모든 CPU의 백트레이스 출력 |
| s | Sync | 파일 시스템 동기화 |