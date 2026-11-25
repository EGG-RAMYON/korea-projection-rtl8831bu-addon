# 구현 방식과 변경 범위

| 후보 | 소스에서 확인한 제약 | 결정 |
|---|---|---|
| 원본 파일을 보존하는 독립 서비스 | KP의 `dg_pick`, `dg_usb`, `dg_seen`은 동일 프로세스의 내부 함수입니다. 공식 `kp_verify` 이후에 이들을 확장할 공개 인터페이스가 없습니다. 독립 AP 서비스는 wlan0, hostapd, DHCP, HMG-API 상태를 중복 관리합니다. | 공식 KP v1.8.0에서 범위 초과 |
| NEMESIS LivePatch | `native/livepatch.c`의 설치 검사에서 파일 대상은 `/system/`으로 시작해야 합니다. KP의 실행 파일과 목록은 `/data/nemesis/apps`에 있습니다. | 해당 파일에 적용 불가 |
| 원본 v1.8.0 전용 패치 | NEMESIS는 `depends`의 정확한 버전 제약을 지원하고 후크에서 서비스 중지·재시작이 가능합니다. 공식 스크립트와 목록의 SHA-256 검증 및 두 파일 복원 가능. | 구현 |
| KP Extension Hook | 서명·해시 확인 뒤 공식 서비스가 드라이버 등록과 개별 초기화 훅을 직접 호출할 수 있습니다. 업스트림이 버전 관리하는 확장 계약이 필요합니다. | 후속 기여 방향 |

검토 기준은 [공식 KP v1.8.0 릴리스](https://github.com/StopDragon/korea-projection/releases/tag/v1.8.0)와 [NEMESIS 903687e7](https://github.com/xwtk/hmg_nemesis/tree/903687e7ce52b5e7d022411e10dede6210cf1b3c)입니다. NEMESIS의 `native/pkg.c`에서 의존성과 설치·제거 후크 순서를, `native/svc.c`에서 서비스 중지 표식과 재시작을, `native/livepatch.c`에서 적용 경로 제한을 확인했습니다. 부팅 이후 실행 주체는 계속 `korea.projection/ap` 하나입니다. 애드온에 [service] 항목을 두지 않습니다.

## 무결성과 호환성

KP가 사용하는 MD5 검사 함수는 유지합니다. 애드온의 사전 검사에서 공식 서비스, 목록, APK, HMG-API ZIP, 각 드라이버 등 공식 배포 파일의 SHA-256을 대조합니다. NEMESIS 설치 후크에서 한 번 더 확인한 뒤 기존 서비스 모드·소유권을 복사하여 파일을 교체합니다. 새 MD5 목록에는 변경한 서비스의 해시 한 행만 달라집니다. AX 모듈과 지원 도구는 애드온 경로에 두고 사용 직전 SHA-256을 대조합니다. 배포 외부 SHA-256은 내려받은 파일의 손상 확인에 사용합니다. 별도 암호학적 서명은 제공하지 않습니다.

전원 손실에 대비해 검사한 원본 두 파일과 복구 표식을 먼저 저장하고 동기화합니다. 두 파일의 이름 교체는 같은 디렉터리에서 각각 원자적으로 수행합니다. 두 파일 전체를 한 번에 교체하는 연산은 아니므로 중간 전원 손실 상태는 공식 검사가 실행을 막고 애드온 제거·복구 후크에서 되돌립니다. 복구 시 원본·패치 어느 쪽 해시에도 맞지 않은 파일은 덮어쓰지 않습니다. 공식 KP의 NEMESIS 메타데이터도 설치 배포본의 SHA-256으로 확인합니다.

대상은 tcc803x, 3.18.24-tcc ARMv7, Android 4.4.2, NX4 HEV 국내형 V039.001.260902입니다. 실차 로그에 표시된 내부 모델 표기 0000과 사용자 제공 S5W_M 표기를 받습니다. 0bda:b831 및 b851만 AX 모듈에 포함합니다. b851과 가상 CD-ROM 0bda:1a2b 전환은 실차 미검증입니다. CD-ROM 전환은 단독 후보, 클래스 08/06/50, SCSI 장치 유형 5가 맞을 때 같은 부팅에서 한 번만 시도합니다. 전원 손실 기록이 남은 경우 애드온 제거·재설치로 기록을 정리한 후에만 재시도합니다. 차량에서 바뀌는 USB ID를 확인한 뒤 로더를 시작합니다.

## 파일·설정과 로그

| 경로 또는 상태 | 작성 주체 및 제거 동작 |
|---|---|
| /data/nemesis/apps/korea.projection/{svc/hotspot.sh,bin/kp-files.md5} | 애드온이 백업 후 교체. 기존 mode·소유자를 복사. 제거 시 해시를 검증하고 복원. 임시명은 각각 .kp-ax-tmp |
| /data/nemesis/apps/korea.projection.rtl8831bu | NEMESIS 애드온 설치 폴더. 모듈·셸 데이터·라이선스. 실행 파일 0755, 다른 파일 0644. 제거 시 NEMESIS가 삭제 |
| /data/nemesis/backup/korea.projection.rtl8831bu | 변경 대상 두 파일과 설치 부팅 ID를 담은 ready. 디렉터리 0700. 검증된 복원·서비스 처리 이후 삭제 |
| /data/nemesis/backup/korea.projection/dongle.driver, dongle.cdrom | 애드온의 부팅별 모듈 선택·eject 기록 및 .tmp. 제거 시 정리. 기존 KP의 동글 토글·실패 추적·Wi-Fi 백업은 KP가 계속 관리 |
| /data/local/tmp/korea.projection | AX LTE 검증 상태 표식 둘을 제거 시 정리. SCSI 임시 노드는 전환 끝에 제거. KP 자체 진단·실행 파일은 기존 로직에서 관리 |
| /data/nemesis/logs/korea.projection/ap.log{,.1} | 원래 KP 제보 및 512 KiB 기준 1회전 사용. AX 차단 결과는 상태 변경 시 기록. 애드온 전용 상시 로그 파일 없음 |
| /data/nemesis/{packages.db,services.db,pids,queue} 및 /data/local/tmp/nemesis/stage | NEMESIS가 레코드·런타임 상태 관리. 외부에서 직접 수정하지 않음 |
| /data/misc/wifi/hostapd-kp.conf, wpa_supplicant.conf 및 CRC, Settings.Global Wi-Fi 값과 KP 속성 | 기존 KP의 AP·백업 정책을 계속 사용. AX만 채널 36·20 MHz·KR. 애드온 제거는 KP 제거가 아니므로 공용 KP 설정 백업을 보존 |
| /data/misc/wifi/softap.conf 및 /securedata/wifi/softap.conf, ConnectivitySSID | 기존 KP에서 읽는 값을 사용. 애드온 코드에 쓰기 동작 없음 |
| /system | 설치·복구 후크에서 쓰지 않음. 공식 KP·HMG-API의 기존 기능 파일·패치 관리는 원래 KP 동작으로 유지 |
| 커널, 네트워크 | 공식 AOA Guard의 기존 sysfs·/dev 동작을 재사용. AX AP의 wlan0 IPv4·IPv6 FORWARD만 차단. 두 계열 규칙을 확인하지 못하면 AX AP를 시작하지 않음. 모듈이 남은 채 제거하면 다음 재부팅에서 모듈과 규칙을 없애고 공식 서비스를 시작 |

LTE 차단은 AX AP와 헤드유닛 사이를 경유하는 전달 트래픽에 적용합니다. 공식 KP의 AC·내장 경로와 차량 자체 통신은 기존 동작을 유지합니다. 방화벽이 외부에서 재작성되면 기존 KP 점검 주기에 재확인합니다. 재작성 순간부터 다음 점검 사이와 헤드유닛의 다른 트래픽은 실차에서 별도 검증이 필요합니다.

## 베타 시도에서 재사용한 근거

기존 beta.3 개발 소스, Hotfix 2 USB, JMK GPL 드라이버 산출물과 실차 제보를 확보했습니다. 처음에는 Android 셸에서 `printf: not found`가 발생했습니다. 드라이버 선택 부팅 기록은 패키지 BusyBox의 printf로 작성합니다. 다음 시도에서는 리포트에 B831 열거, rtl8851bu 바인딩, wlan0 확인과 반복 hostapd 종료가 남았습니다. 이전 작업에서 채널 149 문제를 찾아 KR/36/20 MHz로 변경했고 사용자가 무선 AA 연결 성공을 확인했습니다. 그 성공을 정식 v1.8.0 기반 애드온의 실차 결과로 사용하지 않습니다.
