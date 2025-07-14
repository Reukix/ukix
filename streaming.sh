#!/bin/bash

VER='1.0.1'

UA_BROWSER="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
UA_SEC_CH_UA='"Google Chrome";v="125", "Chromium";v="125", "Not.A/Brand";v="24"'
UA_ANDROID="Mozilla/5.0 (Linux; Android 10; Pixel 4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36"

# --- Utility Functions ---

color_print() {
    Font_Black="\033[30m"
    Font_Red="\033[31m"
    Font_Green="\033[32m"
    Font_Yellow="\033[33m"
    Font_Blue="\033[34m"
    Font_Purple="\033[35m"
    Font_SkyBlue="\033[36m"
    Font_White="\033[37m"
    Font_Suffix="\033[0m"
}

command_exists() {
    command -v "$1" > /dev/null 2>&1
}

gen_uuid() {
    if [ -f /proc/sys/kernel/random/uuid ]; then
        local genuuid=$(cat /proc/sys/kernel/random/uuid)
        echo "${genuuid}"
        return 0
    fi

    if command_exists uuidgen; then
        local genuuid=$(uuidgen)
        echo "${genuuid}"
        return 0
    fi

    if command_exists powershell && [ "$OS_WINDOWS" == 1 ]; then
        local genuuid=$(powershell -c "[guid]::NewGuid().ToString()")
        echo "${genuuid}"
        return 0
    fi

    return 1
}

gen_random_str() {
    if [ -z "$1" ]; then
        echo -e "${Font_Red}Length missing.${Font_Suffix}"
        exit 1
    fi
    local randomstr=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c "$1")
    echo "${randomstr}"
}

resolve_ip_address() {
    if [ -z "$1" ]; then
        echo -e "${Font_Red}Domain missing.${Font_Suffix}"
        exit 1
    fi
    if [ -z "$2" ]; then
        echo -e "${Font_Red}DNS Record type missing.${Font_Suffix}"
        exit 1
    fi

    local domain="$1"
    local recordType="$2"

    if command_exists nslookup && [ "$OS_WINDOWS" != 1 ]; then
        local nslookupExists=1
    fi
    if command_exists dig; then
        local digExists=1
    fi
    if [ "$OS_IOS" == 1 ]; then
        local nslookupExists=0
        local digExists=0
    fi

    if [ "$nslookupExists" == 1 ]; then
        if [ "$recordType" == 'AAAA' ]; then
            local result=$(nslookup -q=AAAA "${domain}" | grep -woP "Address: \K[\d:a-f]+")
            echo "${result}"
            return
        else
            local result=$(nslookup -q=A "${domain}" | grep -woP "Address: \K[\d.]+")
            echo "${result}"
            return
        fi
    fi
    if [ "$digExists" == 1 ]; then
        if [ "$recordType" == 'AAAA' ]; then
            local result=$(dig +short "${domain}" AAAA)
            echo "${result}"
            return
        else
            local result=$(dig +short "${domain}" A)
            echo "${result}"
            return
        fi
    fi

    if [ "$recordType" == 'AAAA' ]; then
        local pingArgs='-6 -c 1 -w 1 -W 1'
        [ "$OS_ANDROID" == 1 ] && pingArgs='-c 1 -w 1 -W 1'
        local result=$(ping6 ${pingArgs} "${domain}" 2>/dev/null | head -n 1 | grep -woP '\s\(\K[\d:a-f]+')
        echo "${result}"
        return
    else
        local pingArgs='-4 -c 1 -w 1 -W 1'
        [ "$OS_ANDROID" == 1 ] && pingArgs='-c 1 -w 1 -W 1'
        local result=$(ping ${pingArgs} "${domain}" 2>/dev/null | head -n 1 | grep -woP '\s\(\K[\d.]+')
        echo "${result}"
        return
    fi
}

validate_ip_address() {
    if [ -z "$1" ]; then
        echo -e "${Font_Red}Param IP Address is missing.${Font_Suffix}"
        exit 1
    fi

    if echo "$1" | awk '{$1=$1; print}' | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
        return 4
    fi
    echo "$1" | awk '{$1=$1; print}' | grep -Eq '^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|^(([0-9a-fA-F]{1,4}:){1,7}|:):([0-9a-fA-F]{1,4}:){1,7}|:$|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}$|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}$|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}$|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}$|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}$|([0-9a-fA-F]{1,4}:){1}(:[0-9a-fA-F]{1,4}){1,6}$|:(:[0-9a-fA-F]{1,4}){1,7}$|((([0-9a-fA-F]{1,4}:){1,4}:|:):(([0-9a-fA-F]{1,4}:){0,1}[0-9a-fA-F]{1,4}){1,4})$'
    if [ "$?" == 0 ]; then
        return 6
    fi

    return 1
}

validate_intranet() {
    if [ -z "$1" ]; then
        echo -e "${Font_Red}Param missing.${Font_Suffix}"
    fi
    # See https://en.wikipedia.org/wiki/Reserved_IP_addresses
    local tmpresult=$(echo "$1" | grep -E '(^|\s)(10\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])|172\.(1[6-9]|2[0-9]|3[01])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])|192\.168\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])|100\.([6-9][4-9]|1[0-2][0-7])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])|169\.254\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])|192\.88\.99\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])|192\.0\.(0|2)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])|198\.(1[89])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])|198\.51\.100\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])|203\.0\.113\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])|2[23][4-9]\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])|233\.252\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])|(24[0-9]|25[0-5])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9]))(\s|$)')
    if [ -z "$tmpresult" ]; then
        return 1
    fi

    return 0
}

check_net_connctivity() {
    if [ -z "$1" ]; then
        echo -e "${Font_Red}Param missing.${Font_Suffix}"
        exit 1
    fi

    if [ "$1" == 4 ]; then
        local result1=$(curl -4 ${CURL_OPTS} -fs 'https://www.google.com' -o /dev/null -s -w '%{http_code}\n')
        if [ "$result1" != '000' ]; then
            return 0
        fi
    fi

    if [ "$1" == 6 ]; then
        local result2=$(curl -6 ${CURL_OPTS} -fs 'https://www.google.com' -o /dev/null -s -w '%{http_code}\n')
        if [ "$result2" != '000' ]; then
            return 0
        fi
    fi

    return 1
}

check_os_type() {
    OS_TYPE=''
    local ifLinux=$(uname -a | grep -i 'linux')
    local ifFreeBSD=$(uname -a | grep -i 'freebsd')
    local ifTermux=$(echo "$PWD" | grep -i 'termux')
    local ifMacOS=$(uname -a | grep -i 'Darwin')
    local ifMinGW=$(uname -a | grep -i 'MINGW')
    local ifCygwin=$(uname -a | grep -i 'CYGWIN')
    local ifAndroid=$(uname -a | grep -i 'android')
    local ifiSh=$(uname -a | grep -i '\-ish')

    if [ -n "$ifLinux" ] && [ -z "$ifAndroid" ] && [ -z "$ifiSh" ]; then
        OS_TYPE='linux'
        OS_LINUX=1
        return
    fi
    if [ -n "$ifTermux" ]; then
        OS_TYPE='termux'
        OS_TERMUX=1
        OS_ANDROID=1
        return
    fi
    if [ -n "$ifMacOS" ]; then
        OS_TYPE='macos'
        OS_MACOS=1
        return
    fi
    if [ -n "$ifMinGW" ]; then
        OS_TYPE='msys'
        OS_WINDOWS=1
        return
    fi
    if [ -n "$ifCygwin" ]; then
        OS_TYPE='cygwin'
        OS_WINDOWS=1
        return
    fi
    if [ -n "$ifFreeBSD" ]; then
        OS_TYPE='freebsd'
        OS_FREEBSD=1
        return
    fi
    if [ -n "$ifAndroid" ]; then
        OS_TYPE='android'
        OS_ANDROID=1
        return
    fi
    if [ -n "$ifiSh" ]; then
        OS_TYPE='ish'
        OS_IOS=1
        return
    fi

    echo -e "${Font_Red}Unsupported OS Type.${Font_Suffix}"
    exit 1
}

check_dependencies() {
    CURL_SSL_CIPHERS_OPT=''

    if [ "$OS_TYPE" == 'linux' ]; then
        source /etc/os-release
        if [ -z "$ID" ]; then
            echo -e "${Font_Red}Unsupported Linux OS Type.${Font_Suffix}"
            exit 1
        fi

        case "$ID" in
        debian|devuan|kali)
            OS_NAME='debian'
            PKGMGR='apt'
            ;;
        ubuntu)
            OS_NAME='ubuntu'
            PKGMGR='apt'
            ;;
        centos|fedora|rhel|almalinux|rocky|amzn)
            OS_NAME='rhel'
            PKGMGR='dnf'
            ;;
        arch|archarm)
            OS_NAME='arch'
            PKGMGR='pacman'
            ;;
        alpine)
            OS_NAME='alpine'
            PKGMGR='apk'
            ;;
        *)
            OS_NAME="$ID"
            PKGMGR='apt'
            ;;
        esac
    fi

    if [ -z $(echo 'e' | grep -P 'e' 2>/dev/null) ]; then
        echo -e "${Font_Red}command 'grep' function is incomplete, please install the full version first.${Font_Suffix}"
        exit 1
    fi

    if ! command_exists curl; then
        echo -e "${Font_Red}command 'curl' is missing, please install it first.${Font_Suffix}"
        exit 1
    fi

    if ! gen_uuid >/dev/null; then
        echo -e "${Font_Red}command 'uuidgen' is missing, please install it first.${Font_Suffix}"
        exit 1
    fi

    if ! command_exists openssl; then
        echo -e "${Font_Red}command 'openssl' is missing, please install it first.${Font_Suffix}"
        exit 1
    fi

    if [ "$OS_MACOS" == 1 ]; then
        if ! command_exists md5sum; then
            echo -e "${Font_Red}command 'md5sum' is missing, please install it first.${Font_Suffix}"
            exit 1
        fi
        if ! command_exists sha256sum; then
            echo -e "${Font_Red}command 'sha256sum' is missing, please install it first.${Font_Suffix}"
            exit 1
        fi
    fi

    if [ "$OS_NAME" == 'debian' ] || [ "$OS_NAME" == 'ubuntu' ]; then
        local os_version=$(echo "$VERSION_ID" | tr -d '.')
        if [ "$os_version" == "2004" ] || [ "$os_version" == "10" ] || [ "$os_version" == "11" ]; then
            CURL_SSL_CIPHERS_OPT='-k --ciphers DEFAULT@SECLEVEL=1'
        fi
    fi

    if command_exists usleep; then
        USE_USLEEP=1
    fi
}

process() {
    LANGUAGE='zh' # Hardcode to Chinese as per saved preference
    CURL_OPTS="$USE_NIC $USE_PROXY $X_FORWARD ${CURL_SSL_CIPHERS_OPT} --max-time 10 --retry 3 --retry-max-time 20"
}

delay() {
    if [ -z $1 ]; then
        exit 1
    fi
    local val=$1
    if [ "$USE_USLEEP" == 1 ]; then
        usleep $(awk 'BEGIN{print '$val' * 1000000}')
        return 0
    fi
    sleep $val
    return 0
}

count_run_times() {
    local tmpresult=$(curl ${CURL_OPTS} -s "https://polished-wildflower-aa1f.colorroom.workers.dev/")
    TODAY_RUN_TIMES=$(echo "$tmpresult" | sed -n 's/.*"dailyCount":\([0-9]*\).*/\1/p')
    TOTAL_RUN_TIMES=$(echo "$tmpresult" | sed -n 's/.*"totalCount":\([0-9]*\).*/\1/p')
}

download_extra_data() {
    MEDIA_COOKIE=$(curl ${CURL_OPTS} -s "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/cookies")
    IATACODE=$(curl ${CURL_OPTS} -s "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/reference/IATACode.txt")
    IATACODE2=$(curl ${CURL_OPTS} -s "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/reference/IATACode2.txt")
    if [ -z "$MEDIA_COOKIE" ] || [ -z "$IATACODE" ] || [ -z "$IATACODE2" ]; then
        echo -e "${Font_Red}Extra data download failed.${Font_Suffix}"
        delay 3
    fi
}

get_ip_info() {
    LOCAL_IP_ASTERISK=''
    LOCAL_ISP=''
    local local_ip=$(curl ${CURL_DEFAULT_OPTS} -s https://api64.ipify.org --user-agent "${UA_BROWSER}")
    local get_local_isp=$(curl ${CURL_DEFAULT_OPTS} -s "https://api.ip.sb/geoip/${local_ip}" -H 'accept: */*;q=0.8,application/signed-exchange;v=b3;q=0.7' -H 'accept-language: en-US,en;q=0.9' -H "sec-ch-ua: ${UA_SEC_CH_UA}" -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-dest: document' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: none' -H 'sec-fetch-user: ?1' -H 'upgrade-insecure-requests: 1' --user-agent "${UA_BROWSER}")

    if [ -z "$local_ip" ]; then
        echo -e "${Font_Red}Failed to Query IP Address.${Font_Suffix}"
    fi
    if [ -z "$get_local_isp" ]; then
        echo -e "${Font_Red}Failed to Query IP Info.${Font_Suffix}"
    fi

    validate_ip_address "$local_ip"
    local resp="$?"
    if [ "$resp" == 4 ]; then
        LOCAL_IP_ASTERISK=$(awk -F"." '{print $1"."$2".*.*"}' <<<"${local_ip}")
    fi
    if [ "$resp" == 6 ]; then
        LOCAL_IP_ASTERISK=$(awk -F":" '{print $1":"$2":"$3":*:*"}' <<<"${local_ip}")
    fi

    LOCAL_ISP=$(echo "$get_local_isp" | sed -n 's/.*"organization":"\([^"]*\)".*/\1/p')
}

show_region() {
    echo -e "${Font_Yellow} ---${1}---${Font_Suffix}"
}

# --- Test Functions for Multination ---
function MediaUnlockTest_Dazn() {
    if [ "${USE_IPV6}" == 1 ]; then
        echo -n -e "\r Dazn:\t\t\t\t\t${Font_Red}IPv6 Is Not Currently Supported${Font_Suffix}\n"
        return
    fi

    local tmpresult=$(curl ${CURL_DEFAULT_OPTS} -s 'https://startup.core.indazn.com/misl/v5/Startup'   -H 'accept: */*'   -H 'accept-language: zh-CN,zh;q=0.9'   -H 'content-type: application/json'   -H 'origin: https://www.dazn.com'   -H 'priority: u=1, i'   -H 'referer: https://www.dazn.com/'   -H 'sec-ch-ua: "Not)A;Brand";v="8", "Chromium";v="138", "Microsoft Edge";v="138"'   -H 'sec-ch-ua-mobile: ?0'   -H 'sec-ch-ua-platform: "Windows"'   -H 'sec-fetch-dest: empty'   -H 'sec-fetch-mode: cors'   -H 'sec-fetch-site: cross-site'   -H 'x-session-id: fd264e77-79d5-480c-a514-a275b649da14'   --data-raw '{"Version":"2","LandingPageKey":"generic","Languages":"zh-CN","Platform":"web","Manufacturer":"","PromoCode":"","PlatformAttributes":{}}' --user-agent "${UA_BROWSER}")
    if [ -z "$tmpresult" ]; then
        echo -n -e "\r Dazn:\t\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    if echo "$tmpresult" | grep -qi "Security policy has been breached"; then
        echo -n -e "\r Dazn:\t\t\t\t\t${Font_Red}IP Banned by Dazn${Font_Suffix}\n"
        return
    fi

    local result=$(echo "$tmpresult" | grep -woP '"isAllowed"\s{0,}:\s{0,}\K(false|true)')
    local region=$(echo "$tmpresult" | grep -woP '"GeolocatedCountry"\s{0,}:\s{0,}"\K[^"]+' | tr a-z A-Z)
    case "$result" in
        'false') echo -n -e "\r Dazn:\t\t\t\t\t${Font_Red}No${Font_Suffix}\n" ;;
        'true') echo -n -e "\r Dazn:\t\t\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n" ;;
        *) echo -n -e "\r Dazn:\t\t\t\t\t${Font_Red}Failed (Error: ${result})${Font_Suffix}\n" ;;
    esac
}

function MediaUnlockTest_DisneyPlus() {
    if [ "${USE_IPV6}" == 1 ]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}IPv6 Is Not Currently Supported${Font_Suffix}\n"
        return
    fi

    local tempresult=$(curl ${CURL_DEFAULT_OPTS} -s 'https://disney.api.edge.bamgrid.com/devices' -X POST -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -H "content-type: application/json; charset=UTF-8" -d '{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","attributes":{}}' --user-agent "${UA_BROWSER}")
    if [ -z "$tempresult" ]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local is403=$(echo "$tempresult" | grep -i '403 ERROR')
    if [ -n "$is403" ]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}No (IP Banned By Disney+)${Font_Suffix}\n"
        return
    fi

    local assertion=$(echo "$tempresult" | grep -woP '"assertion"\s{0,}:\s{0,}"\K[^"]+')
    if [ -z "$assertion" ]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}Failed (Error: PAGE ERROR)${Font_Suffix}\n"
        return
    fi

    local preDisneyCookie=$(echo "$MEDIA_COOKIE" | sed -n '1p')
    local disneyCookie=$(echo "$preDisneyCookie" | sed "s/DISNEYASSERTION/${assertion}/g")
    local tokenContent=$(curl ${CURL_DEFAULT_OPTS} -s 'https://disney.api.edge.bamgrid.com/token' -X POST -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "${disneyCookie}" --user-agent "${UA_BROWSER}")

    local isBlocked=$(echo "$tokenContent" | grep -i 'forbidden-location')
    local is403=$(echo "$tokenContent" | grep -i '403 ERROR')

    if [ -n "$isBlocked" ] || [ -n "$is403" ]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}No (IP Banned By Disney+ 1)${Font_Suffix}\n"
        return
    fi

    local fakeContent=$(echo "$MEDIA_COOKIE" | sed -n '8p')
    local refreshToken=$(echo "$tokenContent" | grep -woP '"refresh_token"\s{0,}:\s{0,}"\K[^"]+')
    local disneyContent=$(echo "$fakeContent" | sed "s/ILOVEDISNEY/${refreshToken}/g")
    local tmpresult=$(curl ${CURL_DEFAULT_OPTS} -sL 'https://disney.api.edge.bamgrid.com/graph/v1/device/graphql' -X POST -H "authorization: ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "${disneyContent}" --user-agent "${UA_BROWSER}")

    local previewcheck=$(curl ${CURL_DEFAULT_OPTS} -sL 'https://disneyplus.com' -w '%{url_effective}\n' -o /dev/null --user-agent "${UA_BROWSER}")
    local isUnavailable=$(echo "$previewcheck" | grep -E 'preview|unavailable')
    local region=$(echo "$tmpresult" | grep -woP '"countryCode"\s{0,}:\s{0,}"\K[^"]+')
    local inSupportedLocation=$(echo "$tmpresult" | grep -woP '"inSupportedLocation"\s{0,}:\s{0,}\K(false|true)')

    if [ -z "$region" ]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        return
    fi
    if [ "$region" == 'JP' ]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Green}Yes (Region: JP)${Font_Suffix}\n"
        return
    fi
    if [ -n "$isUnavailable" ]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        return
    fi
    if [ "$inSupportedLocation" == 'false' ]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Yellow}Available For [Disney+ ${region}] Soon${Font_Suffix}\n"
        return
    fi
    if [ "$inSupportedLocation" == 'true' ]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
        return
    fi

    echo -n -e "\r Disney+:\t\t\t\t${Font_Red}Failed (Error: ${inSupportedLocation}_${region})${Font_Suffix}\n"
}

function MediaUnlockTest_Netflix() {
    local tmpresult1=$(curl ${CURL_DEFAULT_OPTS} -fsL 'https://www.netflix.com/title/81280792' -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7'   -H 'accept-language: en-US,en;q=0.9'   -b 'flwssn=d2c72c47-49e9-48da-b7a2-2dc6d7ca9fcf; nfvdid=BQFmAAEBEMZa4XMYVzVGf9-kQ1HXumtAKsCyuBZU4QStC6CGEGIVznjNuuTerLAG8v2-9V_kYhg5uxTB5_yyrmqc02U5l1Ts74Qquezc9AE-LZKTo3kY3g%3D%3D; SecureNetflixId=v%3D3%26mac%3DAQEAEQABABSQHKcR1d0sLV0WTu0lL-BO63TKCCHAkeY.%26dt%3D1745376277212; NetflixId=v%3D3%26ct%3DBgjHlOvcAxLAAZuNS4_CJHy9NKJPzUV-9gElzTlTsmDS1B59TycR-fue7f6q7X9JQAOLttD7OnlldUtnYWXL7VUfu9q4pA0gruZKVIhScTYI1GKbyiEqKaULAXOt0PHQzgRLVTNVoXkxcbu7MYG4wm1870fZkd5qrDOEseZv2WIVk4xIeNL87EZh1vS3RZU3e-qWy2tSmfSNUC-FVDGwxbI6-hk3Zg2MbcWYd70-ghohcCSZp5WHAGXg_xWVC7FHM3aOUVTGwRCU1RgGIg4KDKGr_wsTRRw6HWKqeA..; gsid=09bb180e-fbb1-4bf6-adcb-a3fa1236e323; OptanonConsent=isGpcEnabled=0&datestamp=Wed+Apr+23+2025+10%3A47%3A11+GMT%2B0800+(%E4%B8%AD%E5%9B%BD%E6%A0%87%E5%87%86%E6%97%B6%E9%97%B4)&version=202411.1.0&browserGpcFlag=0&isIABGlobal=false&hosts=&consentId=f13f841e-c75d-4f95-ab04-d8f581cac53e&interactionCount=0&isAnonUser=1&landingPath=https%3A%2F%2Fwww.netflix.com%2Fsg-zh%2Ftitle%2F81280792&groups=C0001%3A1%2CC0002%3A1%2CC0003%3A1%2CC0004%3A1'   -H 'priority: u=0, i'   -H 'sec-ch-ua: "Microsoft Edge";v="135", "Not-A.Brand";v="8", "Chromium";v="135"'   -H 'sec-ch-ua-mobile: ?0'   -H 'sec-ch-ua-model: ""'   -H 'sec-ch-ua-platform: "Windows"'   -H 'sec-ch-ua-platform-version: "15.0.0"'   -H 'sec-fetch-dest: document'   -H 'sec-fetch-mode: navigate'   -H 'sec-fetch-site: none'   -H 'sec-fetch-user: ?1'   -H 'upgrade-insecure-requests: 1' --user-agent "${UA_BROWSER}")
    local tmpresult2=$(curl ${CURL_DEFAULT_OPTS} -fsL 'https://www.netflix.com/title/70143836' -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7'   -H 'accept-language: en-US,en;q=0.9'   -b 'flwssn=d2c72c47-49e9-48da-b7a2-2dc6d7ca9fcf; nfvdid=BQFmAAEBEMZa4XMYVzVGf9-kQ1HXumtAKsCyuBZU4QStC6CGEGIVznjNuuTerLAG8v2-9V_kYhg5uxTB5_yyrmqc02U5l1Ts74Qquezc9AE-LZKTo3kY3g%3D%3D; SecureNetflixId=v%3D3%26mac%3DAQEAEQABABSQHKcR1d0sLV0WTu0lL-BO63TKCCHAkeY.%26dt%3D1745376277212; NetflixId=v%3D3%26ct%3DBgjHlOvcAxLAAZuNS4_CJHy9NKJPzUV-9gElzTlTsmDS1B59TycR-fue7f6q7X9JQAOLttD7OnlldUtnYWXL7VUfu9q4pA0gruZKVIhScTYI1GKbyiEqKaULAXOt0PHQzgRLVTNVoXkxcbu7MYG4wm1870fZkd5qrDOEseZv2WIVk4xIeNL87EZh1vS3RZU3e-qWy2tSmfSNUC-FVDGwxbI6-hk3Zg2MbcWYd70-ghohcCSZp5WHAGXg_xWVC7FHM3aOUVTGwRCU1RgGIg4KDKGr_wsTRRw6HWKqeA..; gsid=09bb180e-fbb1-4bf6-adcb-a3fa1236e323; OptanonConsent=isGpcEnabled=0&datestamp=Wed+Apr+23+2025+10%3A47%3A11+GMT%2B0800+(%E4%B8%AD%E5%9B%BD%E6%A0%87%E5%87%86%E6%97%B6%E9%97%B4)&version=202411.1.0&browserGpcFlag=0&isIABGlobal=false&hosts=&consentId=f13f841e-c75d-4f95-ab04-d8f581cac53e&interactionCount=0&isAnonUser=1&landingPath=https%3A%2F%2Fwww.netflix.com%2Fsg-zh%2Ftitle%2F81280792&groups=C0001%3A1%2CC0002%3A1%2CC0003%3A1%2CC0004%3A1'   -H 'priority: u=0, i'   -H 'sec-ch-ua: "Microsoft Edge";v="135", "Not-A.Brand";v="8", "Chromium";v="135"'   -H 'sec-ch-ua-mobile: ?0'   -H 'sec-ch-ua-model: ""'   -H 'sec-ch-ua-platform: "Windows"'   -H 'sec-ch-ua-platform-version: "15.0.0"'   -H 'sec-fetch-dest: document'   -H 'sec-fetch-mode: navigate'   -H 'sec-fetch-site: none'   -H 'sec-fetch-user: ?1'   -H 'upgrade-insecure-requests: 1' --user-agent "${UA_BROWSER}")

    if [ -z "${tmpresult1}" ] || [ -z "${tmpresult2}" ]; then
        echo -n -e "\r Netflix:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local result1=$(echo ${tmpresult1} | grep 'Oh no!')
    local result2=$(echo ${tmpresult2} | grep 'Oh no!')

    if [ -n "${result1}" ] && [ -n "${result2}" ]; then
        echo -n -e "\r Netflix:\t\t\t\t${Font_Yellow}Originals Only${Font_Suffix}\n"
        return
    fi
    
    if [ -z "${result1}" ] || [ -z "${result2}" ]; then
        local region=$(echo "$tmpresult1" | grep -o 'data-country="[A-Z]*"' | sed 's/.*="\([A-Z]*\)"/\1/' | head -n1)
        echo -n -e "\r Netflix:\t\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
        return
    fi

    echo -n -e "\r Netflix:\t\t\t\t\t${Font_Red}Failed${Font_Suffix}\n"
}

function MediaUnlockTest_YouTube_Premium() {
    local tmpresult=$(curl ${CURL_DEFAULT_OPTS} -sL 'https://www.youtube.com/premium' -H 'accept-language: en-US,en;q=0.9' -H 'cookie: YSC=FSCWhKo2Zgw; VISITOR_PRIVACY_METADATA=CgJERRIEEgAgYQ%3D%3D; PREF=f7=4000; __Secure-YEC=CgtRWTBGTFExeV9Iayjele2yBjIKCgJERRIEEgAgYQ%3D%3D; SOCS=CAISOAgDEitib3FfaWRlbnRpdHlmcm9udGVuZHVpc2VydmVyXzIwMjQwNTI2LjAxX3AwGgV6aC1DTiACGgYIgMnpsgY; VISITOR_INFO1_LIVE=Di84mAIbgKY; __Secure-BUCKET=CGQ' --user-agent "${UA_BROWSER}")
    if [ -z "$tmpresult" ]; then
        echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local isCN=$(echo "$tmpresult" | grep 'www.google.cn')

    if [ -n "$isCN" ]; then
        echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}No${Font_Suffix} ${Font_Green} (Region: CN)${Font_Suffix} \n"
        return
    fi

    local isNotAvailable=$(echo "$tmpresult" | grep -i 'Premium is not available in your country')
    local region=$(echo "$tmpresult" | grep -woP '"INNERTUBE_CONTEXT_GL"\s{0,}:\s{0,}"\K[^"]+')
    local isAvailable=$(echo "$tmpresult" | grep -i 'ad-free')

    if [ -n "$isNotAvailable" ]; then
        echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}No${Font_Suffix}\n"
        return
    fi
    if [ -z "$region" ]; then
        local region='UNKNOWN'
    fi
    if [ -n "$isAvailable" ]; then
        echo -n -e "\r YouTube Premium:\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
        return
    fi

    echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}Failed (Error: PAGE ERROR)${Font_Suffix}\n"
}

function MediaUnlockTest_PrimeVideo() {
    if [ "${USE_IPV6}" == 1 ]; then
        echo -n -e "\r Amazon Prime Video:\t\t\t${Font_Red}IPv6 Is Not Currently Supported${Font_Suffix}\n"
        return
    fi

    local tmpresult=$(curl ${CURL_DEFAULT_OPTS} -sL 'https://www.primevideo.com' --user-agent "${UA_BROWSER}")
    if [ -z "$tmpresult" ]; then
        echo -n -e "\r Amazon Prime Video:\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local isBlocked=$(echo "$tmpresult" | grep -i 'isServiceRestricted')
    local region=$(echo "$tmpresult" | grep -woP '"currentTerritory":"\K[^"]+' | head -n 1)

    if [ -z "$isBlocked" ] && [ -z "$region" ]; then
        echo -n -e "\r Amazon Prime Video:\t\t\t${Font_Red}Failed (Error: PAGE ERROR)${Font_Suffix}\n"
        return
    fi
    if [ -n "$isBlocked" ]; then
        echo -n -e "\r Amazon Prime Video:\t\t\t${Font_Red}No (Service Not Available)${Font_Suffix}\n"
        return
    fi
    if [ -n "$region" ]; then
        echo -n -e "\r Amazon Prime Video:\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
        return
    fi

    echo -n -e "\r Amazon Prime Video:\t\t\t${Font_Red}Failed (Error: Unknown Region)${Font_Suffix}\n"
}

function MediaUnlockTest_TVBAnywhere() {
    if [ "${USE_IPV6}" == 1 ]; then
        echo -n -e "\r TVBAnywhere+:\t\t\t\t${Font_Red}IPv6 Is Not Currently Supported${Font_Suffix}\n"
        return
    fi

    local tmpresult=$(curl ${CURL_DEFAULT_OPTS} -s 'https://uapisfm.tvbanywhere.com.sg/geoip/check/platform/android' -H 'accept: */*;q=0.8,application/signed-exchange;v=b3;q=0.7' -H 'accept-language: en-US,en;q=0.9' -H "sec-ch-ua: ${UA_SEC_CH_UA}" -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-dest: document' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: none' -H 'sec-fetch-user: ?1' -H 'upgrade-insecure-requests: 1' --user-agent "${UA_BROWSER}")
    if [ -z "$tmpresult" ]; then
        echo -n -e "\r TVBAnywhere+:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local result=$(echo "$tmpresult" | grep -woP '"allow_in_this_country"\s{0,}:\s{0,}\K(false|true)')
    if [ -z "$result" ]; then
        echo -n -e "\r TVBAnywhere+:\t\t\t\t${Font_Red}Failed (Error: PAGE ERROR)${Font_Suffix}\n"
        return
    fi

    case "$result" in
        'true') echo -n -e "\r TVBAnywhere+:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n" ;;
        'false') echo -n -e "\r TVBAnywhere+:\t\t\t\t${Font_Red}No${Font_Suffix}\n" ;;
        *) echo -n -e "\r TVBAnywhere+:\t\t\t\t${Font_Red}Failed (Error: Unknown)${Font_Suffix}\n" ;;
    esac
}

function MediaUnlockTest_Spotify() {
    local tmpresult=$(curl ${CURL_DEFAULT_OPTS} -s 'https://spclient.wg.spotify.com/signup/public/v1/account' -d "birth_day=11&birth_month=11&birth_year=2000&collect_personal_info=undefined&creation_flow=&creation_point=https%3A%2F%2Fwww.spotify.com%2Fhk-en%2F&displayname=Gay%20Lord&gender=male&iagree=1&key=a1e486e2729f46d6bb368d6b2bcda326&platform=www&referrer=&send-email=0&thirdpartyemail=0&identifier_token=AgE6YTvEzkReHNfJpO114514" -X POST -H "Accept-Language: en" --user-agent "${UA_BROWSER}")
    if [ -z "$tmpresult" ]; then
        echo -n -e "\r Spotify Registration:\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local statusCode=$(echo "$tmpresult" | grep -woP '"status"\s{0,}:\s{0,}\K\d+')
    local region=$(echo "$tmpresult" | grep -woP '"country"\s{0,}:\s{0,}"\K[^"]+')
    local isLaunched=$(echo "$tmpresult" | grep -woP '"is_country_launched"\s{0,}:\s{0,}\K(false|true)')

    if [ -z "$statusCode" ]; then
        echo -n -e "\r Spotify Registration:\t\t\t${Font_Red}Failed (Error: PAGE ERROR)${Font_Suffix}\n"
        return
    fi
    if [ "$statusCode" == '320' ] || [ "$statusCode" == '120' ]; then
        echo -n -e "\r Spotify Registration:\t\t\t${Font_Red}No${Font_Suffix}\n"
        return
    fi
    if [ -z "$isLaunched" ] || [ -z "$region" ]; then
        echo -n -e "\r Spotify Registration:\t\t\t${Font_Red}Failed (Error: PAGE ERROR)${Font_Suffix}\n"
        return
    fi
    if [ "$isLaunched" == 'false' ]; then
        echo -n -e "\r Spotify Registration:\t\t\t${Font_Red}No${Font_Suffix}\n"
        return
    fi
    if [ "$statusCode" == '311' ]; then
        echo -n -e "\r Spotify Registration:\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
        return
    fi

    echo -n -e "\r Spotify Registration:\t\t\t${Font_Red}Failed (Error: $statusCode)${Font_Suffix}\n"
}

function RegionTest_oneTrust() {
    local tmpresult=$(curl ${CURL_DEFAULT_OPTS} -s 'https://geolocation.onetrust.com/cookieconsentpub/v1/geo/location'  --user-agent "${UA_BROWSER}")
    if [ -z "$tmpresult" ]; then
        echo -n -e "\r OneTrust Region:\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local region=$(echo "$tmpresult" | grep -woP '"country"\s{0,}:\s{0,}"\K[^"]+')
    local stateName=$(echo "$tmpresult" | grep -woP '"stateName"\s{0,}:\s{0,}"\K[^"]+')
    if [ -z "$region" ]; then
        echo -n -e "\r OneTrust Region:\t\t\t${Font_Red}Failed (Error: PAGE ERROR)${Font_Suffix}\n"
        return
    fi
    if [ -z "$stateName" ]; then
        local stateName='Unknown'
    fi

    echo -n -e "\r OneTrust Region:\t\t\t${Font_Green}${region} [${stateName}]${Font_Suffix}\n"
}

function RegionTest_iQYI() {
    if [ "${USE_IPV6}" == 1 ]; then
        echo -n -e "\r iQyi Oversea Region:\t\t\t${Font_Red}IPv6 Is Not Currently Supported${Font_Suffix}\n"
        return
    fi

    local tmpresult=$(curl ${CURL_DEFAULT_OPTS} -sL 'https://www.iq.com/' -w "_TAG_%{http_code}_TAG_" -o /dev/null --user-agent "${UA_BROWSER}" -D -)

    local httpCode=$(echo "$tmpresult" | grep '_TAG_' | awk -F'_TAG_' '{print $2}')
    if [ "$httpCode" == '000' ]; then
        echo -n -e "\r iQyi Oversea Region:\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local region=$(echo "$tmpresult" | grep -woP 'mod=\K[a-z]+' | tr a-z A-Z)
    if [ -z "$region" ]; then
        echo -n -e "\r iQyi Oversea Region:\t\t\t${Font_Red}Failed (Error: Country Code Not Found)${Font_Suffix}\n"
        return
    fi

    if [ "$region" == 'NTW' ]; then
        region='TW'
    fi

    echo -n -e "\r iQyi Oversea Region:\t\t\t${Font_Green}${region}${Font_Suffix}\n"
}

function RegionTest_Bing() {
    local tmpresult=$(curl ${CURL_DEFAULT_OPTS} -s 'https://www.bing.com/search?q=curl' --user-agent "${UA_BROWSER}")
    if [ -z "$tmpresult" ]; then
        echo -n -e "\r Bing Region:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local isCN=$(echo "$tmpresult" | grep 'cn.bing.com')
    local region=$(echo "$tmpresult" | grep -woP 'Region\s{0,}:\s{0,}"\K[^"]+')

    if [ -n "$isCN" ]; then
        local region='CN'
        echo -n -e "\r Bing Region:\t\t\t\t${Font_Yellow}${region}${Font_Suffix}\n"
        return
    fi

    local isRisky=$(echo "$tmpresult" | grep 'sj_cook.set("SRCHHPGUSR","HV"')

    if [ -n "$isRisky" ]; then
        echo -n -e "\r Bing Region:\t\t\t\t${Font_Yellow}${region} (Risky)${Font_Suffix}\n"
        return
    fi

    echo -n -e "\r Bing Region:\t\t\t\t${Font_Green}${region}${Font_Suffix}\n"
}

function RegionTest_Apple() {
    local result=$(curl ${CURL_DEFAULT_OPTS} -sL 'https://gspe1-ssl.ls.apple.com/pep/gcc')
    if [ -z "$result" ]; then
        echo -n -e "\r Apple Region:\t\t\t\t${Font_Red}Failed${Font_Suffix}\n"
        return
    else
        echo -n -e "\r Apple Region:\t\t\t\t${Font_Green}${result}${Font_Suffix}\n"
        return
    fi
}

function RegionTest_YouTubeCDN() {
    local tmpresult=$(curl ${CURL_DEFAULT_OPTS} -s 'https://redirector.googlevideo.com/report_mapping' --user-agent "${UA_BROWSER}")
    if [ -z "$tmpresult" ]; then
        echo -n -e "\r YouTube CDN:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local iata=$(echo "$tmpresult" | grep '=>' | awk "NR==1" | awk '{print $3}' | cut -f2 -d'-' | cut -c 1-3 | tr a-z A-Z)
    local isIDC=$(echo "$tmpresult" | grep 'router')
    local isIataFound1=$(echo "$IATACODE" | grep -w "$iata")
    local isIataFound2=$(echo "$IATACODE2" | grep -w "$iata")

    if [ -z "$iata" ]; then
        echo -n -e "\r YouTube CDN:\t\t\t\t${Font_Red}Failed (Error: Location Unknown)${Font_Suffix}\n"
        return
    fi
    if [ -z "$isIataFound1" ] && [ -z "$isIataFound2" ]; then
        echo -n -e "\r YouTube CDN:\t\t\t\t${Font_Red}Failed (Error: IATA: ${iata} Not Found)${Font_Suffix}\n"
        return
    fi
    if [ -n "$isIataFound1" ]; then
        local location=$(echo "$IATACODE" | grep -w "$iata" | awk -F'|' '{print $1}' | awk '{$1=$1; print}')
    fi
    if [ -z "$isIataFound1" ] && [ -n "$isIataFound2" ]; then
        local location=$(echo "$IATACODE2" | grep -w "$iata" | awk -F',' '{print $2}' | awk '{$1=$1; print}' | tr A-Z a-z | sed 's/\b[a-z]/\U&/g')
    fi

    if [ -z "$isIDC" ]; then
        local cdnISP=$(echo "$tmpresult" | awk 'NR==1' | awk '{print $3}' | cut -f1 -d'-' | tr a-z A-Z)
        echo -n -e "\r YouTube CDN:\t\t\t\t${Font_Yellow}[${cdnISP}] in [${location}]${Font_Suffix}\n"
        return
    fi
    if [ -n "$isIDC" ]; then
        echo -n -e "\r YouTube CDN:\t\t\t\t${Font_Green}${location}${Font_Suffix}\n"
        return
    fi

    echo -n -e "\r YouTube CDN:\t\t\t\t${Font_Red}Failed (Error: Unknown)${Font_Suffix}\n"
}

function RegionTest_NetflixCDN() {
    local tmpresult=$(curl ${CURL_DEFAULT_OPTS} -s 'https://api.fast.com/netflix/speedtest/v2?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm&urlCount=1' -w '_TAG_%{http_code}' --user-agent "${UA_BROWSER}")
    local httpCode=$(echo "$tmpresult" | grep '_TAG_' | awk -F'_TAG_' '{print $2}')
    local respContent=$(echo "$tmpresult" | awk -F'_TAG_' '{print $1}')
    if [ "$httpCode" == '000' ]; then
        echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi
    if [ "$httpCode" == '403' ]; then
        echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Red}Failed (IP Banned By Netflix)${Font_Suffix}\n"
        return
    fi

    local cdnDomain=$(echo "$respContent" | grep -woP '"url":"\K[^"]+' | awk -F'[/:]' '{print $4}')
    if [ -z "$cdnDomain" ]; then
        echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Red}Failed (Error: PAGE ERROR)${Font_Suffix}\n"
        return
    fi

    if [ "${USE_IPV6}" == 1 ]; then
        local cdnIP=$(resolve_ip_address "$cdnDomain" 'AAAA')
    else
        local cdnIP=$(resolve_ip_address "$cdnDomain" 'A')
    fi

    if [ -z "$cdnIP" ]; then
        echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Red}Failed (CDN IP Not Found)${Font_Suffix}\n"
        return
    fi

    if ! validate_intranet "$cdnIP"; then
        local tmpresult1=$(curl ${CURL_DEFAULT_OPTS} -s "https://api.ip.sb/geoip/${cdnIP}" -H 'accept: */*;q=0.8,application/signed-exchange;v=b3;q=0.7' -H 'accept-language: en-US,en;q=0.9' -H "sec-ch-ua: ${UA_SEC_CH_UA}" -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-dest: document' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: none' -H 'sec-fetch-user: ?1' -H 'upgrade-insecure-requests: 1' --user-agent "${UA_BROWSER}")
        if [ -z "$tmpresult1" ]; then
            echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Red}Failed (Network Connection 1)${Font_Suffix}\n"
            return
        fi

        local cdnISP=$(echo "$tmpresult1" | grep -woP '"isp"\s{0,}:\s{0,}"\K[^"]+')
        if [ -z "$cdnISP" ]; then
            echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Red}Failed (Error: No ISP Info Found)${Font_Suffix}\n"
            return
        fi
    else
        cdnISP='Hidden by a VPN'
    fi

    local iata=$(echo "$cdnDomain" | cut -f3 -d'-' | sed 's/.\{3\}$//' | tr a-z A-Z)

    local isIataFound1=$(echo "$IATACODE" | grep -w "$iata")
    local isIataFound2=$(echo "$IATACODE2" | grep -w "$iata")

    if [ -n "$isIataFound1" ]; then
        local location=$(echo "$IATACODE" | grep -w "$iata" | awk -F'|' '{print $1}' | awk '{$1=$1; print}')
    fi
    if [ -z "$isIataFound1" ] && [ -n "$isIataFound2" ]; then
        local location=$(echo "$IATACODE2" | grep -w "$iata" | awk -F',' '{print $2}' | awk '{$1=$1; print}' | tr A-Z a-z | sed 's/\b[a-z]/\U&/g')
    fi

    if [ -z "$location" ]; then
        echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Red}Failed (Error: IATA CODE ERROR)${Font_Suffix}\n"
        return
    fi

    if [ "$cdnISP" == 'Netflix Streaming Services' ]; then
        echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Green}${location}${Font_Suffix}\n"
        return
    else
        echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Yellow}[${cdnISP}] in [${location}]${Font_Suffix}\n"
        return
    fi

    echo -n -e "\r Netflix Preferred CDN:\t\t\t${Font_Red}Failed (Error: Unknown)${Font_Suffix}\n"
}

function WebTest_OpenAI() {
    local tmpresult1=$(curl ${CURL_DEFAULT_OPTS} -s 'https://api.openai.com/compliance/cookie_requirements' -H 'authority: api.openai.com' -H 'accept: */*' -H 'accept-language: en-US,en;q=0.9' -H 'authorization: Bearer null' -H 'content-type: application/json' -H 'origin: https://platform.openai.com' -H 'referer: https://platform.openai.com/' -H "sec-ch-ua: ${UA_SEC_CH_UA}" -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-dest: empty' -H 'sec-fetch-mode: cors' -H 'sec-fetch-site: same-site' --user-agent "${UA_BROWSER}")
    local tmpresult2=$(curl ${CURL_DEFAULT_OPTS} -s 'https://ios.chat.openai.com/' -H 'authority: ios.chat.openai.com' -H 'accept: */*;q=0.8,application/signed-exchange;v=b3;q=0.7' -H 'accept-language: en-US,en;q=0.9' -H "sec-ch-ua: ${UA_SEC_CH_UA}" -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-dest: document' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: none' -H 'sec-fetch-user: ?1' -H 'upgrade-insecure-requests: 1' --user-agent "${UA_BROWSER}")
    if [ -z "$tmpresult1" ]; then
        echo -n -e "\r ChatGPT:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi
    if [ -z "$tmpresult2" ]; then
        echo -n -e "\r ChatGPT:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local result1=$(echo "$tmpresult1" | grep -i 'unsupported_country')
    local result2=$(echo "$tmpresult2" | grep -i 'VPN')
    if [ -z "$result2" ] && [ -z "$result1" ]; then
        echo -n -e "\r ChatGPT:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n"
        return
    fi
    if [ -n "$result2" ] && [ -n "$result1" ]; then
        echo -n -e "\r ChatGPT:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        return
    fi
    if [ -z "$result1" ] && [ -n "$result2" ]; then
        echo -n -e "\r ChatGPT:\t\t\t\t${Font_Yellow}No (Only Available with Web Browser)${Font_Suffix}\n"
        return
    fi
    if [ -n "$result1" ] && [ -z "$result2" ]; then
        echo -n -e "\r ChatGPT:\t\t\t\t${Font_Yellow}No (Only Available with Mobile APP)${Font_Suffix}\n"
        return
    fi

    echo -n -e "\r ChatGPT:\t\t\t\t${Font_Red}Failed (Error: Unknown)${Font_Suffix}\n"
}

function WebTest_Gemini() {
    local tmpresult=$(curl ${CURL_DEFAULT_OPTS} -sL "https://gemini.google.com" --user-agent "${UA_BROWSER}")
    if [[ "$tmpresult" = "curl"* ]]; then
        echo -n -e "\r Google Gemini:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi
    result=$(echo "$tmpresult" | grep -q '45631641,null,true' && echo "Yes" || echo "")
    countrycode=$(echo "$tmpresult" | grep -o ',2,1,200,"[A-Z]\{3\}"' | sed 's/,2,1,200,"//;s/"//' || echo "")
    if [ -n "$result" ] && [ -n "$countrycode" ]; then
        echo -n -e "\r Google Gemini:\t\t\t\t${Font_Green}Yes (Region: $countrycode)${Font_Suffix}\n"
        return
    elif [ -n "$result" ]; then
        echo -n -e "\r Google Gemini:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n"
        return
    else
        echo -n -e "\r Google Gemini:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        return
    fi
}

function WebTest_Claude() {
    local UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
    local response=$(curl ${CURL_DEFAULT_OPTS} -s -L -A "${UA_Browser}" -o /dev/null -w '%{url_effective}' "https://claude.ai/")
    if [ -z "$response" ]; then
        echo -e "\r Claude:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi
    if [[ "$response" == "https://claude.ai/" ]]; then
        echo -e "\r Claude:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n"
    elif [[ "$response" == "https://www.anthropic.com/app-unavailable-in-region" ]]; then
        echo -e "\r Claude:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
    else
        echo -e "\r Claude:\t\t\t\t${Font_Yellow}Unknown (${response})${Font_Suffix}\n"
    fi
}

function WebTest_Wikipedia_Editable() {
    local tmpresult=$(curl ${CURL_DEFAULT_OPTS} -s 'https://zh.wikipedia.org/w/index.php?title=Wikipedia%3A%E6%B2%99%E7%9B%92&action=edit' --user-agent "${UA_BROWSER}")
    if [ -z "$tmpresult" ]; then
        echo -n -e "\r Wikipedia Editability:\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local result=$(echo "$tmpresult" | grep -i 'Banned')
    if [ -z "$result" ]; then
        echo -n -e "\r Wikipedia Editability:\t\t\t${Font_Green}Yes${Font_Suffix}\n"
        return
    fi

    echo -n -e "\r Wikipedia Editability:\t\t\t${Font_Red}No${Font_Suffix}\n"
}

function WebTest_GooglePlayStore() {
    local result=$(curl ${CURL_DEFAULT_OPTS} -sL 'https://play.google.com/'   -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7'   -H 'accept-language: en-US;q=0.9'   -H 'priority: u=0, i'   -H 'sec-ch-ua: "Chromium";v="131", "Not_A Brand";v="24", "Google Chrome";v="131"'   -H 'sec-ch-ua-mobile: ?0'   -H 'sec-ch-ua-platform: "Windows"'   -H 'sec-fetch-dest: document'   -H 'sec-fetch-mode: navigate'   -H 'sec-fetch-site: none'   -H 'sec-fetch-user: ?1'   -H 'upgrade-insecure-requests: 1' -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36' | grep -oP '<div class="yVZQTb">\K[^<(]+')
    if [ -z "$result" ]; then
        echo -n -e "\r Google Play Store:\t\t\t${Font_Red}Failed${Font_Suffix}\n"
        return
    else
        echo -n -e "\r Google Play Store:\t\t\t${Font_Green}${result}${Font_Suffix}\n"
        return
    fi
}

function WebTest_GoogleSearchCAPTCHA() {
    local tmpresult=$(curl ${CURL_DEFAULT_OPTS} -sL 'https://www.google.com/search?q=curl&oq=curl&gs_lcrp=EgZjaHJvbWUyBggAEEUYOdIBBzg1MmowajGoAgCwAgE&sourceid=chrome&ie=UTF-8' -H 'accept: */*;q=0.8,application/signed-exchange;v=b3;q=0.7' -H 'accept-language: en-US,en;q=0.9' -H "sec-ch-ua: ${UA_SEC_CH_UA}" -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-model: ""' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-ch-ua-platform-version: "15.0.0"' -H 'sec-ch-ua-wow64: ?0' -H 'sec-fetch-dest: document' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: none' -H 'sec-fetch-user: ?1' -H 'upgrade-insecure-requests: 1' --user-agent "${UA_BROWSER}")
    if [ -z "$tmpresult" ]; then
        echo -n -e "\r Google Search CAPTCHA Free:\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local isBlocked=$(echo "$tmpresult" | grep -iE 'unusual traffic from|is blocked|unaddressed abuse')
    local isOK=$(echo "$tmpresult" | grep -i 'curl')

    if [ -z "$isBlocked" ] && [ -z "$isOK" ]; then
        echo -n -e "\r Google Search CAPTCHA Free:\t\t${Font_Red}Failed (Error: PAGE ERROR)${Font_Suffix}\n"
        return
    fi
    if [ -n "$isBlocked" ]; then
        echo -n -e "\r Google Search CAPTCHA Free:\t\t${Font_Red}No${Font_Suffix}\n"
        return
    fi
    if [ -n "$isOK" ]; then
        echo -n -e "\r Google Search CAPTCHA Free:\t\t${Font_Green}Yes${Font_Suffix}\n"
        return
    fi

    echo -n -e "\r Google Search CAPTCHA Free:\t\t${Font_Red}Failed (Error: Unknown)${Font_Suffix}\n"
}

function GameTest_Steam() {
    if [ "${USE_IPV6}" == 1 ]; then
        echo -n -e "\r Steam Currency:\t\t\t${Font_Red}IPv6 Is Not Currently Supported${Font_Suffix}\n"
        return
    fi

    local tmpresult=$(curl ${CURL_DEFAULT_OPTS} -sL 'https://store.steampowered.com/app/761830' --user-agent "${UA_BROWSER}")
    if [ -z "$tmpresult" ]; then
        echo -n -e "\r Steam Currency:\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    local result=$(echo "$tmpresult" | grep 'priceCurrency' | cut -d '"' -f4)
    if [ -z "$result" ]; then
        echo -n -e "\r Steam Currency:\t\t\t${Font_Red}Failed (Error: PAGE ERROR)${Font_Suffix}\n"
        return
    fi

    echo -n -e "\r Steam Currency:\t\t\t${Font_Green}${result}${Font_Suffix}\n"
}

function WebTest_Reddit() {
    if [ "${USE_IPV6}" == 1 ]; then
        echo -n -e "\r Reddit:\t\t\t\t${Font_Red}IPv6 Is Not Currently Supported${Font_Suffix}\n"
        return
    fi

    local result=$(curl ${CURL_DEFAULT_OPTS} -fsL 'https://www.reddit.com/' -w %{http_code} -o /dev/null --user-agent "${UA_BROWSER}")
    case "$result" in
        '000') echo -n -e "\r Reddit:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n" ;;
        '403') echo -n -e "\r Reddit:\t\t\t\t${Font_Red}No${Font_Suffix}\n" ;;
        '200') echo -n -e "\r Reddit:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n" ;;
        *) echo -n -e "\r Reddit:\t\t\t\t${Font_Red}Failed (Error: ${result})${Font_Suffix}\n" ;;
    esac
}

function GameTest_SDGGGE() {
    local result=$(echo -n "1CR6PntuLeI3yaCYAZdOPxn18bOFYJxUiYtcavqqAHDCjc3C/wozplHYwfhykUStp7Bb/LAhV8aWQkS9sLliHCIgXBvDsWe4pwXvV3cSXkoaBfL23/zytEHlAatOi/32UVYLJhyUsegCRMMGREr2fXqyx970imQ35hqWVj/MRTHS9Bi8iqo9nIqSDTcQqVn3BbuyhJcz52nhfSda2may3QVHkH9QDdFjW9S/2re2cxE3iaE/DUbjB9H8KUpihQB1Emf88I0241ea7CAI1jHel6aZ5Ul4XjTf8ug3Rl/T80A=" | base64 -d | curl ${CURL_DEFAULT_OPTS} -s  'https://api.gl.eternal.channel.or.jp/api/pvt/consent/view?user_id=649635267711712178' -X POST -H 'Host: api.gl.eternal.channel.or.jp' -H 'X-Content-Is-Encrypted: True' -H 'X-Language: hk' -H 'Accept: application/protobuf' -H 'X-Unity-Version: 2022.3.45f1' -H 'X-Master-Url: https://clientdata.gl.eternal.channel.or.jp/prd-gl/catalogs/hr0phpfWDVahMJGQIk2OSd6hy35YpQZVKYAo6lKeld-9scMGJw2KTnBDGbS04Gw-i25avFTH55K-yU9TCX2OkQ.json' -H 'X-Language-Master-Url: https://clientdata.gl.eternal.channel.or.jp/prd-gl/language_catalogs/hk/F-HORjFKHLai8nLXUdPyQRqzexZNPKIn2O36Hgd2Bxm2RysBNS0-PQHQwfHXEOONog0w5yULtewBaVk-Ndf6nQ.json' -H 'x-app-version-hash: 20928' -H 'x-token: e5df59f1-8588-4477-a887-5fe854895493Mj0jmtfbgIhQOUmHQE1W7sLq7G5eSBqcFWqldSPjy6s=' -H 'Accept-Language: zh-CN,zh-Hans;q=0.9' -H 'User-Agent: GETERNAL/25041500 CFNetwork/3826.400.120 Darwin/24.3.0' -H 'Connection: keep-alive' -H 'Content-Type: application/protobuf' --data-binary @- -w %{http_code} -o /dev/null)

    case "$result" in
        '000') echo -n -e "\r SD Gundam G Generation Eternal:\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n" ;;
        '200') echo -n -e "\r SD Gundam G Generation Eternal:\t${Font_Green}Yes${Font_Suffix}\n" ;;
        '483') echo -n -e "\r SD Gundam G Generation Eternal:\t${Font_Red}No${Font_Suffix}\n" ;;
        *) echo -n -e "\r SD Gundam G Generation Eternal:\t${Font_Red}Failed (Error: ${result})${Font_Suffix}\n" ;;
    esac
}
# --- End of Test Functions ---


function echo_result() {
    for ((i=0;i<${#array[@]};i++)); do
        echo "$result" | grep "${array[i]}"
        delay 0.03
    done
}

function Global_UnlockTest() {
    echo ""
    echo "============[ Multination ]============"
    local result=$(
        MediaUnlockTest_Dazn &
        MediaUnlockTest_DisneyPlus &
        MediaUnlockTest_Netflix &
        MediaUnlockTest_YouTube_Premium &
        MediaUnlockTest_PrimeVideo &
        MediaUnlockTest_TVBAnywhere &
        MediaUnlockTest_Spotify &
        RegionTest_oneTrust &
        RegionTest_iQYI &
    )
    wait
    local array=("Dazn:" "Disney+:" "Netflix:" "YouTube Premium:" "Amazon Prime Video:" "TVBAnywhere+:" "Spotify Registration:" "OneTrust Region:" "iQyi Oversea Region:")
    echo_result ${result} ${array}
    local result=$(
        RegionTest_Bing &
        RegionTest_Apple &
        RegionTest_YouTubeCDN &
        RegionTest_NetflixCDN &
        WebTest_OpenAI &
        WebTest_Gemini &
        WebTest_Claude &
        WebTest_Wikipedia_Editable &
        WebTest_GooglePlayStore &
        WebTest_GoogleSearchCAPTCHA &
        GameTest_Steam &
    )
    wait
    local array=("Bing Region:" "Apple Region:" "YouTube CDN:" "Netflix Preferred CDN:" "ChatGPT:" "Google Gemini:" "Claude:" "Wikipedia Editability:" "Google Play Store:" "Google Search CAPTCHA Free:" "Steam Currency:")
    echo_result ${result} ${array}
    show_region Forum
    WebTest_Reddit
    show_region Game
    GameTest_SDGGGE
    echo "======================================="
}

function showScriptTitle() {
    echo -e " [流媒体平台及游戏区域限制测试]"
    echo ''
    echo -e "${Font_Green}项目地址${Font_Suffix} ${Font_Yellow}https://github.com/lmc999/RegionRestrictionCheck ${Font_Suffix}"
    echo -e "${Font_Green}BUG 反馈或使用交流可加 TG 群组${Font_Suffix} ${Font_Yellow}https://t.me/gameaccelerate ${Font_Suffix}"
    echo ''
    echo -e " ** 测试时间: $(date)"
    echo -e " ** 版本: ${VER}"
    echo ''
}

function showNetworkInfo() {
    echo '--------------------------------'
    get_ip_info
    echo -e " ${Font_SkyBlue}** 您的网络为: ${LOCAL_ISP} (${LOCAL_IP_ASTERISK})${Font_Suffix}"
    echo ''
}

function checkIPConn() {
    if [ -z "$1" ]; then
        echo -e "${Font_Red}Param missing.${Font_Suffix}"
        exit 1
    fi

    local netType="$1"
    
    if [ "$1" == 4 ] && [ "$NETWORK_TYPE" == 6 ]; then
        return
    fi

    if [ "$1" == 6 ] && [ "$NETWORK_TYPE" == 4 ] ; then
        return
    fi
    
    if [ "$netType" == 4 ]; then
        echo ''
        echo -e " ${Font_SkyBlue}** 正在测试 IPv4 解锁情况${Font_Suffix}"
        if ! check_net_connctivity 4 ; then
            echo -e "${Font_SkyBlue}当前主机不支持 IPv4，跳过...${Font_Suffix}"
            USE_IPV4=0
            return
        fi

        USE_IPV4=1
        CURL_DEFAULT_OPTS="-4 ${CURL_OPTS}"
        showNetworkInfo
        return
    fi
    if [ "$netType" == 6 ]; then
        echo ''
        echo -e " ${Font_SkyBlue}** 正在测试 IPv6 解锁情况${Font_Suffix}"
        if ! check_net_connctivity 6 ; then
            echo -e "${Font_SkyBlue}当前主机不支持 IPv6，跳过...${Font_Suffix}"
            USE_IPV6=0
            return
        fi

        USE_IPV6=1
        CURL_DEFAULT_OPTS="-6 ${CURL_OPTS}"
        showNetworkInfo
        return
    fi
}

function showGoodbye() {
    echo -e "${Font_Green}本次测试已结束，感谢使用此脚本${Font_Suffix}"
    echo -e ''
    echo -e "${Font_Yellow}检测脚本当天运行次数: ${TODAY_RUN_TIMES}; 共计运行次数: ${TOTAL_RUN_TIMES}${Font_Suffix}"
    echo -e ''
}

# --- Main Execution Block ---

main() {
    color_print
    check_os_type
    check_dependencies
    process "$@"
    clear
    
    showScriptTitle
    count_run_times
    download_extra_data
    clear

    USE_IPV4=0
    USE_IPV6=0

    # Test IPv4
    checkIPConn 4
    if [ "$USE_IPV4" -eq 1 ]; then
        Global_UnlockTest
    fi

    # Test IPv6
    checkIPConn 6
    if [ "$USE_IPV6" -eq 1 ]; then
        Global_UnlockTest
    fi

    showGoodbye
}

main "$@"
