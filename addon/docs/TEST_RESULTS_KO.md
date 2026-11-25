# 검증 결과

| 범위 | 결과 |
|---|---|
| 컴파일 | Debian 13 호스트에서 AOSP arm-eabi-gcc 4.7로 RTL8851BU 및 RTL88x2BU 교차 컴파일. ARMv7 모듈과 SCSI eject 도우미 생성 |
| RTL8851BU ABI | 공식 RTL88x2BU의 vermagic과 일치. USB 별칭 B831/B851, 로드 인자, 추가 심볼의 패치된 커널 소스 export, 주요 9개 타입의 DWARF 크기·멤버 배치 확인 |
| RTL88x2BU 비교 | 공식 배포 파일과 재빌드 결과의 모듈 인자·srcversion·USB 별칭·미정의 심볼 일치. 배포 모듈과 바이트가 다름. 애드온은 차량의 공식 모듈을 사용 |
| 원본 테스트 | Android API 19 SDK로 LayoutTest, ReportTest, UiTest와 mksh 문법 검사·변수 검사 완료. 릴리스 소스에 테스트 입력이 없는 AA 및 WLAN 진단, HMG-API 동기화 검사 3개는 건너뜀 |
| 애드온 | 공식 파일 변조 거부, 패치 및 제거, 실행 권한 보존, B831 모듈 선택·바인딩, AC 경로 및 기본 채널 보존, AX AP 설정, 파일 교체 실패·중단 복구, AX 모듈이 남은 상태의 제거, ZIP 무결성 모의 검증 |
| LTE 차단 | 가짜 IPv4·IPv6 iptables를 사용하여 선두 차단, 중복 방지, IPv6 실패 거부 및 정리 확인. 실차 커널 전달·카운터 확인 필요 |
| 실차 및 WSL | 신규 애드온 및 Ubuntu 20.04 Docker·WSL 실제 실행 미검증. 기존 베타 Hotfix 2에서만 무선 AA 연결 확인 |

모듈의 구조체와 심볼 비교는 오프라인 근거입니다. 대상 커널의 실측 로드, HMG-API 1.0.2와 연결, NEMESIS 설치 화면 동작, 무선 AA/CarPlay, CD-ROM 전환·재삽입은 정차 상태에서 별도 승인 후 확인합니다.
