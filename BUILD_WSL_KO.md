# WSL2에서 v1.0.2 빌드

Ubuntu WSL2와 Docker Desktop의 WSL 통합을 준비합니다. Ubuntu에서 **v1.0.2 릴리스의 전체 소스 묶음**을 내려받은 뒤 다음을 실행합니다.

~~~bash
mkdir -p ~/kp-ax-build
cd ~/kp-ax-build
curl -fLO https://github.com/EGG-RAMYON/korea-projection-rtl8831bu-addon/releases/download/v1.0.2/KP_AX_v1.0.2_GitHub_Publish.zip
echo '32ce925db19972d00f0d132d5a4f5364127b27441af192e90f504f4a1c9a08ef  KP_AX_v1.0.2_GitHub_Publish.zip' | sha256sum -c -
unzip KP_AX_v1.0.2_GitHub_Publish.zip
git clone --branch v1.0.2 ./korea-projection-rtl8831bu-addon.bundle source
cd source
docker version
bash build-wsl.sh both
cd out
sha256sum -c SHA256SUMS
~~~

Git 번들에는 두 커널 드라이버의 전체 소스, 패치, 빌드 스크립트와 Dockerfile이 들어 있습니다. 자세한 빌드 옵션은 번들 안의 BUILD_WSL_KO.md를 참조하십시오. 이 릴리스의 모듈은 Debian에서 AOSP GCC 4.7로 실제 교차 빌드했으며, WSL의 Docker 실행은 별도로 검증하지 않았습니다.
