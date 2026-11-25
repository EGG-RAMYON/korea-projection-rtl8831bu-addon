# Korea Projection RTL8831BU 애드온

ipTIME AX900mini를 Korea Projection v1.8.0과 함께 사용하기 위한 비공식 NEMESIS 애드온입니다. 2026년 11월 25일, 현대 투싼 NX4 HEV 국내형 Gen5W에서 애드온 1.0.2 설치와 무선 Android Auto 연결을 확인했습니다.

| 항목 | 검증 환경 |
|---|---|
| 헤드유닛 | Gen5W AVNT STD G50 WIDE R6, Telechips tcc803x |
| 펌웨어 | NX4HEV.KOR.0000.V039.001.260902 |
| OS / 커널 | Android 4.4.2, Linux 3.18.24-tcc ARMv7 |
| 동글 | ipTIME AX900mini, RTL8831BU |
| 소프트웨어 | 공식 Korea Projection v1.8.0 + 애드온 v1.0.2 |

## 설치와 복구

공식 Korea Projection v1.8.0을 먼저 설치합니다. 이 저장소의 Releases에서 USB 설치 ZIP을 받아 내용물을 FAT32 USB 최상위에 풉니다. 설치 및 제거 순서는 [사용자 안내](addon/docs/README_KO.md)를 따릅니다. 복구 USB ZIP도 Releases에서 받을 수 있습니다. [공식 Korea Projection v1.8.0](https://github.com/StopDragon/korea-projection/releases/tag/v1.8.0)

애드온은 별도 NEMESIS 패키지 ID를 쓰며, 설치할 때 공식 KP의 SHA-256을 검사한 뒤 hotspot.sh와 해당 파일의 무결성 목록을 백업하고 교체합니다. 기존 RTL88x2BU 지원을 함께 유지합니다. [구현 세부 사항](addon/docs/DESIGN_KO.md)

## 소스 및 검증

애드온 코드는 이 저장소에 있습니다. 전체 드라이버 소스와 빌드 입력, 스크립트는 v1.0.2 릴리스의 Git 번들에 포함되어 있습니다.

- [WSL2 빌드](BUILD_WSL_KO.md)
- [공식 KP 대비 서비스 패치](addon/hotspot-v1.8.0.patch)
- [라이선스와 출처](addon/docs/NOTICE.md)

실차 확인은 설치 및 무선 Android Auto 연결까지입니다. CarPlay와 LTE 포워딩 차단은 실차 미검증입니다.
