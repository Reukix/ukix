#!/usr/bin/env bash
check_bash(){
if ((BASH_VERSINFO[0]<4));then
printf 'Reukix ip.sh requires Bash 4 or newer.\n' >&2
exit 1
fi
}
check_bash
Font_B="\033[1m"
Font_D="\033[2m"
Font_I="\033[3m"
Font_U="\033[4m"
Font_Black="\033[30m"
Font_Red="\033[31m"
Font_Green="\033[32m"
Font_Yellow="\033[33m"
Font_Blue="\033[34m"
Font_Purple="\033[35m"
Font_Cyan="\033[36m"
Font_White="\033[37m"
Back_Black="\033[40m"
Back_Red="\033[41m"
Back_Green="\033[42m"
Back_Yellow="\033[43m"
Back_Blue="\033[44m"
Back_Purple="\033[45m"
Back_Cyan="\033[46m"
Back_White="\033[47m"
Font_Suffix="\033[0m"
declare IP=""
declare IPhide
declare fullIP=0
declare YY="cn"
declare -A maxmind
declare -A ipinfo
declare -A scamalytics
declare -A ipregistry
declare -A ipapi
declare -A abuseipdb
declare -A ip2location
declare -A dbip
declare -A ipdata
declare -A ipqs
declare -A tiktok
declare -A disney
declare -A netflix
declare -A youtube
declare -A amazon
declare -A claude
declare -A chatgpt
declare IPV4
declare IPV6
declare IPV4check=1
declare IPV6check=1
declare IPV4work=0
declare IPV6work=0
declare ERRORcode=0
declare mode_help=0
declare -A swarn
declare -A shead
declare -A sbasic
declare -A stype
declare -A sscore
declare -A sfactor
declare -A smedia
declare -A smail
declare -A smailstatus
declare mode_no=0
declare mode_yes=0
declare mode_lite=0
declare uses_ipinfo_location=0
declare mode_json=0
declare mode_output=0
declare ipjson
declare PADDING=""
declare iface=""
declare -a CurlARG=()
declare UA_Browser
declare country_data='[]'
declare dependency_dir=''
declare terminal_page=0
declare -a terminal_reports=()
declare -A sprogress

print_help() {
    if [[ $YY == cn ]]; then
        cat <<'HELP'
Reukix IP 检测
用法  bash ip.sh [选项]
English help  bash ip.sh -Eh

  -4 / -6       仅检测 IPv4 或 IPv6。默认检测两者
  -i 网卡或地址  使用指定网卡或本机 IP 发起检测
  -f            显示完整出口 IP。默认隐藏部分地址
  -j            将 JSON 写到标准输出
  -o 文件       保存到新文件（.json 为 JSON，.ansi 保留颜色，其他后缀为纯文本）
  -l 语言       选择地名语言（cn/en/jp/es/de/fr/ru/pt），默认 cn
  -E            使用英文报告（同 -l en）
  -n            跳过依赖检查
  -y            将缺少的依赖安装到系统（Debian/Ubuntu 默认使用临时目录）
  -h            显示帮助
HELP
    else
        cat <<'HELP'
Reukix IP Check
Usage  bash ip.sh [options]

  -4 / -6       Check only IPv4 or IPv6. The default checks both
  -i source     Use a network interface or local IP address
  -f            Show the full public IP. The default masks part of the address
  -j            Print JSON to standard output
  -o file       Save a new file (.json for JSON, .ansi for color, plain text otherwise)
  -l language   Select the language for place names (cn/en/jp/es/de/fr/ru/pt, default cn)
  -E            Use English for the report (same as -l en)
  -n            Skip the dependency check
  -y            Install missing tools system-wide (Debian/Ubuntu use temporary tools by default)
  -h            Show help
HELP
    fi
}
set_language(){
case "$YY" in
"en"|"jp"|"es"|"de"|"fr"|"ru"|"pt")swarn[1]="ERROR: Unsupported parameters!"
sprogress=([title]="Reukix IP Check" [deps]="Checking dependencies" [temp]="Preparing temporary tools"
    [index]="Refreshing package lists" [unpack]="Unpacking temporary tools" [egress]="Finding public IP"
    [country]="Loading country data" [db]="IP databases" [media]="Streaming and AI"
    [mail]="Email" [dnsbl]="DNS blocklists" [report]="Preparing report"
    [pages]="Space / b to turn pages, q to exit" [close]="Press any key to return")
swarn[2]="ERROR: IP address format error!"
swarn[3]="ERROR: Installing packages requires root or sudo."
swarn[4]="ERROR: Parameter -4 conflicts with -6!"
swarn[6]="ERROR: Parameter -6 conflicts with -4!"
swarn[7]="ERROR: The specified network interface or outbound IP is invalid or does not exist!"
swarn[10]="ERROR: Output file already exist!"
swarn[11]="ERROR: Output file is not writable!"
swarn[40]="ERROR: IPv4 is not available!"
swarn[46]="ERROR: Neither IPv4 nor IPv6 is available!"
swarn[60]="ERROR: IPv6 is not available!"
shead[title]="Reukix IP Report  "
shead[title_lite]="Reukix IP Report (Lite)  "
shead[time_raw]=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
shead[time]="Report Time: ${shead[time_raw]}"
shead[ltitle]=18
shead[ltitle_lite]=25
shead[ltime]=13
sbasic[title]="1. Basic Information (${Font_I}Maxmind Database$Font_Suffix)"
sbasic[title_lite]="1. Basic Information (${Font_I}IPinfo Database$Font_Suffix)"
sbasic[title_with_location_fallback]="1. Basic Information (${Font_I}MaxMind / IPinfo$Font_Suffix)"
sbasic[asn]="ASN:                    "
sbasic[noasn]="Not Assigned"
sbasic[org]="Organization:           "
sbasic[location]="Location:               "
sbasic[map]="Map:                    "
sbasic[city]="City:                   "
sbasic[country]="Actual Region:          "
sbasic[regcountry]="Registered Region:      "
sbasic[continent]="Continent:              "
sbasic[timezone]="Time Zone:              "
sbasic[type]="IP Type:                "
sbasic[type0]=" Geo-consistent "
sbasic[type1]=" Geo-discrepant "
stype[business]=" $Back_Yellow$Font_White$Font_B Business $Font_Suffix "
stype[isp]="   $Back_Green$Font_White$Font_B ISP $Font_Suffix    "
stype[hosting]=" $Back_Red$Font_White$Font_B Hosting $Font_Suffix  "
stype[education]="$Back_Yellow$Font_White$Font_B Education $Font_Suffix "
stype[government]="$Back_Yellow$Font_White$Font_B Government $Font_Suffix"
stype[banking]=" $Back_Yellow$Font_White$Font_B Banking $Font_Suffix  "
stype[organization]="$Back_Yellow$Font_White${Font_B}Organization$Font_Suffix"
stype[military]=" $Back_Yellow$Font_White$Font_B Military $Font_Suffix "
stype[library]=" $Back_Yellow$Font_White$Font_B Library $Font_Suffix  "
stype[cdn]="   $Back_Red$Font_White$Font_B CDN $Font_Suffix    "
stype[lineisp]=" $Back_Green$Font_White$Font_B Line ISP $Font_Suffix "
stype[mobile]="$Back_Green$Font_White$Font_B Mobile ISP $Font_Suffix"
stype[spider]="$Back_Red$Font_White$Font_B Web Spider $Font_Suffix"
stype[reserved]=" $Back_Yellow$Font_White$Font_B Reserved $Font_Suffix "
stype[other]="  $Back_Yellow$Font_White$Font_B Other $Font_Suffix   "
stype[title]="2. IP Type"
stype[db]="Database:  "
stype[usetype]="Usage:     "
stype[comtype]="Company:   "
sscore[verylow]="$Font_Green${Font_B}VeryLow$Font_Suffix"
sscore[low]="$Font_Green${Font_B}Low$Font_Suffix"
sscore[medium]="$Font_Yellow${Font_B}Medium$Font_Suffix"
sscore[high]="$Font_Red${Font_B}High$Font_Suffix"
sscore[veryhigh]="$Font_Red${Font_B}VeryHigh$Font_Suffix"
sscore[elevated]="$Font_Yellow${Font_B}Elevated$Font_Suffix"
sscore[suspicious]="$Font_Yellow${Font_B}Suspicious$Font_Suffix"
sscore[risky]="$Font_Red${Font_B}Risky$Font_Suffix"
sscore[highrisk]="$Font_Red${Font_B}HighRisk$Font_Suffix"
sscore[dos]="$Font_Red${Font_B}DoS$Font_Suffix"
sscore[colon]=": "
sscore[title]="3. Risk Score"
sscore[range]="${Font_Cyan}Levels:         $Font_I$Font_White${Back_Green}VeryLow     Low $Back_Yellow     Medium     $Back_Red High   VeryHigh$Font_Suffix"
sfactor[title]="4. Risk Factors"
sfactor[factor]="DB:  "
sfactor[countrycode]="Region: "
sfactor[proxy]="Proxy:  "
sfactor[tor]="Tor:    "
sfactor[vpn]="VPN:    "
sfactor[server]="Server: "
sfactor[abuser]="Abuser: "
sfactor[robot]="Robot:  "
sfactor[yes]="$Font_Red$Font_B Yes$Font_Suffix"
sfactor[no]="$Font_Green$Font_B No $Font_Suffix"
sfactor[na]="$Font_Green$Font_B N/A$Font_Suffix"
smedia[yes]="  $Back_Green$Font_White Yes $Font_Suffix  "
smedia[no]=" $Back_Red$Font_White Block $Font_Suffix "
smedia[bad]="$Back_Red$Font_White Failed $Font_Suffix "
smedia[pending]="$Back_Yellow$Font_White Pending $Font_Suffix"
smedia[cn]=" $Back_Red$Font_White China $Font_Suffix "
smedia[noprem]="$Back_Red$Font_White NoPrem. $Font_Suffix"
smedia[org]="$Back_Yellow$Font_White NF.Only $Font_Suffix"
smedia[web]="$Back_Yellow$Font_White WebOnly $Font_Suffix"
smedia[app]="$Back_Yellow$Font_White APPOnly $Font_Suffix"
smedia[idc]="  $Back_Yellow$Font_White IDC $Font_Suffix  "
smedia[native]="$Back_Green$Font_White Native $Font_Suffix "
smedia[dns]="$Back_Yellow$Font_White ViaDNS $Font_Suffix "
smedia[unknown]="$Back_Yellow$Font_White Unknown $Font_Suffix"
smedia[limited]="$Back_Yellow$Font_White Limited $Font_Suffix"
smedia[nodata]="         "
smedia[title]="5. Accessibility check for media and AI services"
smedia[meida]="Service: "
smedia[status]="Status:  "
smedia[region]="Region:  "
smedia[type]="Type:    "
smail[title]="6. Email service availability and blacklist detection"
smail[port]="Local Port 25 Outbound: "
smail[yes]="${Font_Green}Available$Font_Suffix"
smail[no]="${Font_Red}Blocked$Font_Suffix"
smail[occupied]="${Font_Yellow}Occupied$Font_Suffix"
smail[blocked]="${Font_Red}Remote Port 25 unreachable​$Font_Suffix"
smail[provider]="Conn: "
smail[dnsbl]="DNSBL database: "
smail[available]="$Font_Suffix${Font_Cyan}Active $Font_B"
smail[clean]="$Font_Suffix${Font_Green}Clean $Font_B"
smail[marked]="$Font_Suffix${Font_Yellow}Marked $Font_B"
smail[blacklisted]="$Font_Suffix${Font_Red}Blacklisted $Font_B"
;;
"cn")swarn[1]="错误：不支持的参数！"
sprogress=([title]="Reukix IP 检测" [deps]="正在检查依赖" [temp]="正在准备临时工具"
    [index]="正在刷新软件包索引" [unpack]="正在解包临时工具" [egress]="正在获取出口 IP"
    [country]="正在读取国家和地区数据" [db]="IP 数据库" [media]="流媒体与 AI"
    [mail]="邮件连通性" [dnsbl]="DNS 黑名单" [report]="正在生成报告"
    [pages]="空格下一页，b 上一页，q 返回" [close]="按任意键返回命令行")
swarn[2]="错误：IP地址格式错误！"
swarn[3]="错误：安装依赖需要 root 或 sudo。"
swarn[4]="错误：参数 -4 与 -6 冲突！"
swarn[6]="错误：参数 -6 与 -4 冲突！"
swarn[7]="错误：指定的网卡或出口IP不存在！"
swarn[10]="错误：输出文件已存在！"
swarn[11]="错误：输出文件不可写！"
swarn[40]="错误：IPV4不可用！"
swarn[46]="错误：IPv4 和 IPv6 均不可用！"
swarn[60]="错误：IPV6不可用！"
shead[title]="Reukix IP 检测报告  "
shead[title_lite]="Reukix IP 检测报告（精简）  "
shead[time_raw]=$(TZ="Asia/Shanghai" date +"%Y-%m-%d %H:%M:%S CST")
shead[time]="报告时间：${shead[time_raw]}"
shead[ltitle]=20
shead[ltitle_lite]=28
shead[ltime]=10
sbasic[title]="一、基础信息（${Font_I}Maxmind 数据库${Font_Suffix}）"
sbasic[title_lite]="一、基础信息（${Font_I}IPinfo 数据库${Font_Suffix}）"
sbasic[title_with_location_fallback]="一、基础信息（${Font_I}MaxMind / IPinfo${Font_Suffix}）"
sbasic[asn]="自治系统号：            "
sbasic[noasn]="未分配"
sbasic[org]="组织：                  "
sbasic[location]="坐标：                  "
sbasic[map]="地图：                  "
sbasic[city]="城市：                  "
sbasic[country]="使用地：                "
sbasic[regcountry]="注册地：                "
sbasic[continent]="洲际：                  "
sbasic[timezone]="时区：                  "
sbasic[type]="IP类型：                "
sbasic[type0]=" 原生IP "
sbasic[type1]=" 广播IP "
stype[business]="   $Back_Yellow$Font_White$Font_B 商业 $Font_Suffix   "
stype[isp]="   $Back_Green$Font_White$Font_B 家宽 $Font_Suffix   "
stype[hosting]="   $Back_Red$Font_White$Font_B 机房 $Font_Suffix   "
stype[education]="   $Back_Yellow$Font_White$Font_B 教育 $Font_Suffix   "
stype[government]="   $Back_Yellow$Font_White$Font_B 政府 $Font_Suffix   "
stype[banking]="   $Back_Yellow$Font_White$Font_B 银行 $Font_Suffix   "
stype[organization]="   $Back_Yellow$Font_White$Font_B 组织 $Font_Suffix   "
stype[military]="   $Back_Yellow$Font_White$Font_B 军队 $Font_Suffix   "
stype[library]="  $Back_Yellow$Font_White$Font_B 图书馆 $Font_Suffix  "
stype[cdn]="   $Back_Red$Font_White$Font_B CDN $Font_Suffix    "
stype[lineisp]="   $Back_Green$Font_White$Font_B 家宽 $Font_Suffix   "
stype[mobile]="   $Back_Green$Font_White$Font_B 手机 $Font_Suffix   "
stype[spider]="   $Back_Red$Font_White$Font_B 蜘蛛 $Font_Suffix   "
stype[reserved]="   $Back_Yellow$Font_White$Font_B 保留 $Font_Suffix   "
stype[other]="   $Back_Yellow$Font_White$Font_B 其他 $Font_Suffix   "
stype[title]="二、IP类型属性"
stype[db]="数据库：   "
stype[usetype]="使用类型： "
stype[comtype]="公司类型： "
sscore[verylow]="$Font_Green${Font_B}极低风险$Font_Suffix"
sscore[low]="$Font_Green${Font_B}低风险$Font_Suffix"
sscore[medium]="$Font_Yellow${Font_B}中风险$Font_Suffix"
sscore[high]="$Font_Red${Font_B}高风险$Font_Suffix"
sscore[veryhigh]="$Font_Red${Font_B}极高风险$Font_Suffix"
sscore[elevated]="$Font_Yellow${Font_B}较高风险$Font_Suffix"
sscore[suspicious]="$Font_Yellow${Font_B}可疑IP$Font_Suffix"
sscore[risky]="$Font_Red${Font_B}存在风险$Font_Suffix"
sscore[highrisk]="$Font_Red${Font_B}高风险$Font_Suffix"
sscore[dos]="$Font_Red${Font_B}建议封禁$Font_Suffix"
sscore[colon]="："
sscore[title]="三、风险评分"
sscore[range]="${Font_Cyan}风险等级：      $Font_I$Font_White${Back_Green}极低         低 $Back_Yellow      中等      $Back_Red 高         极高$Font_Suffix"
sfactor[title]="四、风险因子"
sfactor[factor]="库： "
sfactor[countrycode]="地区：  "
sfactor[proxy]="代理：  "
sfactor[tor]="Tor：   "
sfactor[vpn]="VPN：   "
sfactor[server]="服务器："
sfactor[abuser]="滥用：  "
sfactor[robot]="机器人："
sfactor[yes]="$Font_Red$Font_B 是 $Font_Suffix"
sfactor[no]="$Font_Green$Font_B 否 $Font_Suffix"
sfactor[na]="$Font_Green$Font_B 无 $Font_Suffix"
smedia[yes]=" $Back_Green$Font_White 解锁 $Font_Suffix  "
smedia[no]=" $Back_Red$Font_White 屏蔽 $Font_Suffix  "
smedia[bad]=" $Back_Red$Font_White 失败 $Font_Suffix  "
smedia[pending]="$Back_Yellow$Font_White 待支持 $Font_Suffix "
smedia[cn]=" $Back_Red$Font_White 中国 $Font_Suffix  "
smedia[noprem]="$Back_Red$Font_White 禁会员 $Font_Suffix "
smedia[org]="$Back_Yellow$Font_White 仅自制 $Font_Suffix "
smedia[web]="$Back_Yellow$Font_White 仅网页 $Font_Suffix "
smedia[app]=" $Back_Yellow$Font_White 仅APP $Font_Suffix "
smedia[idc]=" $Back_Yellow$Font_White 机房 $Font_Suffix  "
smedia[native]=" $Back_Green$Font_White 原生 $Font_Suffix  "
smedia[dns]="  $Back_Yellow$Font_White DNS $Font_Suffix  "
smedia[unknown]="$Back_Yellow$Font_White 未判定 $Font_Suffix "
smedia[limited]=" $Back_Yellow$Font_White 限流 $Font_Suffix  "
smedia[nodata]="         "
smedia[title]="五、流媒体及AI服务解锁检测"
smedia[meida]="服务商： "
smedia[status]="状态：   "
smedia[region]="地区：   "
smedia[type]="方式：   "
smail[title]="六、邮局连通性及黑名单检测"
smail[port]="本地25端口出站："
smail[yes]="${Font_Green}可用$Font_Suffix"
smail[no]="${Font_Red}阻断$Font_Suffix"
smail[occupied]="${Font_Yellow}占用$Font_Suffix"
smail[blocked]="${Font_Red}远端25端口不可达​$Font_Suffix"
smail[provider]="通信："
smail[dnsbl]="IP地址黑名单数据库："
smail[available]="$Font_Suffix${Font_Cyan}有效 $Font_B"
smail[clean]="$Font_Suffix${Font_Green}正常 $Font_B"
smail[marked]="$Font_Suffix${Font_Yellow}已标记 $Font_B"
smail[blacklisted]="$Font_Suffix${Font_Red}黑名单 $Font_B"
;;
*)echo -ne "ERROR: Language not supported!"
esac
}
missing_dependencies() {
    local dependency
    for dependency in jq curl bc nc dig nslookup; do
        command -v "$dependency" >/dev/null 2>&1 || printf ' %s' "$dependency"
    done
}

open_terminal_page() {
    [[ -t 0 && -t 1 && -t 2 && ${TERM:-} != dumb && $mode_json == 0 ]] || return 0
    terminal_page=1
    printf '\033[?1049h\033[2J\033[H%s\n\n' "${sprogress[title]}" >&2
}

progress() {
    if (( terminal_page )); then
        printf '\r\033[K%s' "${1-}" >&2
    fi
}

run_probe() {
    progress "$1"
    shift
    "$@"
}

view_terminal_reports() {
    printf '\033[2J\033[H' >&2
    if command -v less >/dev/null 2>&1; then
        printf '%s\n\n' "${terminal_reports[@]}" |
            LESS= LESSHISTFILE=- less -RX -P"${sprogress[pages]}" && return 0
    fi

    local -a lines
    local rows cols per_page pages page=0 key
    mapfile -t lines < <(printf '%s\n\n' "${terminal_reports[@]}")
    while :; do
        read -r rows cols < <(stty size)
        (( rows > 2 )) || rows=24
        (( cols > 0 )) || cols=80
        per_page=$(( (rows - 2) / ((80 + cols - 1) / cols) ))
        (( per_page > 0 )) || per_page=1
        pages=$(( (${#lines[@]} + per_page - 1) / per_page ))
        (( page < pages )) || page=$((pages - 1))
        printf '\033[2J\033[H' >&2
        printf '%s\n' "${lines[@]:page*per_page:per_page}" >&2
        printf '\n[%d/%d]  %s' "$((page + 1))" "$pages" "${sprogress[pages]}" >&2
        IFS= read -rsn1 key || break
        case $key in
            q|Q) break ;;
            b|B) (( page > 0 )) && ((page-=1)) ;;
            ''|' ') (( page + 1 < pages )) && ((page+=1)) ;;
        esac
    done
    return 0
}

cleanup_run() {
    if (( terminal_page )); then
        printf '\033[?1049l' >&2
    fi
    if [[ -n $dependency_dir ]]; then
        rm -rf -- "$dependency_dir"
    fi
}

prepare_deb_tools() {
    local tool pkg binary candidate dir libpath='' loader='' dns=0 archive probe version
    local -a packages=()
    for tool in "$@"; do
        case $tool in
            dig|nslookup) dns=1 ;;
            nc) packages+=(netcat-openbsd) ;;
            *) packages+=("$tool") ;;
        esac
    done
    if (( dns )); then
        # On recent releases dnsutils can be an empty transitional package.
        if [[ $(dpkg-query -W -f='${Status}' bind9-dnsutils 2>/dev/null) == 'install ok installed' ]]; then
            packages+=(bind9-dnsutils)
        else
            packages+=(dnsutils)
        fi
    fi
    dependency_dir=$(mktemp -d "${TMPDIR:-/tmp}/reukix-ip.XXXXXXXX") || return 1
    local root="$dependency_dir/root" cache="$dependency_dir/cache" log="$dependency_dir/apt.log"
    mkdir -p "$root" "$dependency_dir/bin" "$cache/archives/partial" \
        "$dependency_dir/state/lists/partial" "$dependency_dir/log" || return 1

    # Keep apt's package state and update hooks out of the host system.
    cat > "$dependency_dir/apt.conf" <<'APT' || return 1
#clear APT::Update::Pre-Invoke;
#clear APT::Update::Post-Invoke;
#clear APT::Update::Post-Invoke-Success;
#clear DPkg::Pre-Invoke;
#clear DPkg::Post-Invoke;
#clear DPkg::Pre-Install-Pkgs;
APT
    local -a apt=(apt-get -c "$dependency_dir/apt.conf" -o Debug::NoLocking=1
        -o "Dir::State=$dependency_dir/state" -o Dir::State::status=/var/lib/dpkg/status
        -o "Dir::Cache=$cache" -o "Dir::Cache::archives=$cache/archives"
        -o "Dir::Log=$dependency_dir/log" -o Acquire::Languages=none
        -o Acquire::http::Timeout=20 -o Acquire::https::Timeout=20)
    local -a download=(--download-only --no-install-recommends --reinstall -y install "${packages[@]}")

    progress "${sprogress[temp]} · $*"
    if ! compgen -G '/var/lib/apt/lists/*_Packages*' >/dev/null ||
        ! "${apt[@]}" -o Dir::State::lists=/var/lib/apt/lists "${download[@]}" >"$log" 2>&1; then
        progress "${sprogress[index]}"
        "${apt[@]}" update >"$log" 2>&1 || { tail -n 6 "$log" >&2; return 1; }
        progress "${sprogress[temp]} · $*"
        "${apt[@]}" "${download[@]}" >"$log" 2>&1 || { tail -n 6 "$log" >&2; return 1; }
    fi
    progress "${sprogress[unpack]} · $*"
    for archive in "$cache"/archives/*.deb; do
        [[ -f $archive ]] && dpkg-deb -x "$archive" "$root" || return 1
    done
    for dir in "$root"/{usr/lib,lib}/*-linux-* "$root/usr/lib" "$root/lib"; do
        [[ -d $dir ]] || continue
        libpath+=${libpath:+:}$dir
        for candidate in "$dir"/ld-linux*.so.* "$dir"/ld.so.1; do
            [[ ! -f $candidate ]] || loader=$candidate
        done
    done

    # Only the downloaded tools see these libraries. System commands keep their own loader.
    for tool in "$@"; do
        pkg=$tool
        [[ $tool != nc ]] || pkg=nc.openbsd
        for binary in "$root/usr/bin/$pkg" "$root/bin/$pkg"; do
            [[ ! -x $binary ]] || break
        done
        [[ -x $binary ]] || { printf 'Missing executable in package: %s\n' "$pkg" >&2; return 1; }
        {
            printf '#!/bin/bash\n'
            if [[ -n $libpath ]]; then
                printf 'export LD_LIBRARY_PATH=%q${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\n' "$libpath"
            fi
            printf 'exec '
            [[ -z $loader ]] || printf '%q ' "$loader"
            printf '%q "$@"\n' "$binary"
        } > "$dependency_dir/bin/$tool" || return 1
        chmod 700 "$dependency_dir/bin/$tool" || return 1
        case $tool in
            nc)
                version=$(LC_ALL=C "$dependency_dir/bin/nc" -h 2>&1)
                [[ $version == *'OpenBSD netcat'* ]] || return 1
                ;;
            *)
                case $tool in dig) probe=-v ;; nslookup) probe=-version ;; *) probe=--version ;; esac
                "$dependency_dir/bin/$tool" "$probe" >/dev/null || return 1
                ;;
        esac
    done
    export PATH="$dependency_dir/bin:$PATH"
}

install_dependencies(){
local missing
missing=$(missing_dependencies)
[[ -z $missing ]] && return 0
if [[ $mode_yes -eq 0 ]];then
if [[ -r /etc/debian_version ]] && command -v apt-get >/dev/null && command -v dpkg-deb >/dev/null; then
    local -a tools
    read -r -a tools <<< "$missing"
    if prepare_deb_tools "${tools[@]}" && [[ -z $(missing_dependencies) ]]; then
        return 0
    fi
    if [[ $YY == cn ]]; then
        printf '\n临时依赖准备失败，请检查软件源与临时目录。\n' >&2
    else
        printf '\nCould not prepare temporary tools. Check the package sources and temporary directory.\n' >&2
    fi
    return 3
fi
if [[ $YY == cn ]];then
printf '缺少依赖：%s。手动安装或使用 -y 自动安装。\n' "$missing"
else
printf 'Missing dependencies:%s. Install them or rerun with -y.\n' "$missing"
fi
return 3
fi
if [ "$(uname)" == "Darwin" ];then
install_packages "brew" "brew install" "no_sudo"
elif [ -f /etc/os-release ];then
. /etc/os-release
if [[ $(id -u) -ne 0 ]] && ! command -v sudo >/dev/null 2>&1;then
printf '%s\n' "${swarn[3]}"
return 3
fi
case $ID in
ubuntu|debian|linuxmint)install_packages "apt" "apt-get install -y"
;;
rhel|centos|almalinux|rocky|anolis)if
[ "$(echo $VERSION_ID|cut -d '.' -f1)" -ge 8 ]
then
install_packages "dnf" "dnf install -y"
else
install_packages "yum" "yum install -y"
fi
;;
arch|manjaro)install_packages "pacman" "pacman -S --noconfirm"
;;
alpine)install_packages "apk" "apk add"
;;
fedora)install_packages "dnf" "dnf install -y"
;;
alinux)install_packages "yum" "yum install -y"
;;
suse|opensuse*)install_packages "zypper" "zypper install -y"
;;
void)install_packages "xbps" "xbps-install -Sy"
;;
*)echo "Unsupported distribution: $ID"
return 3
esac
elif [ -n "$PREFIX" ];then
install_packages "pkg" "pkg install"
else
echo "Cannot detect distribution because /etc/os-release is missing."
return 3
fi
missing=$(missing_dependencies)
if [[ -n $missing ]];then
printf 'Missing dependencies:%s\n' "$missing"
return 3
fi
}
install_packages(){
local package_manager=$1
local install_command=$2
local no_sudo=$3
printf 'Installing dependencies with %s.\n' "$package_manager"
if [ "$no_sudo" == "no_sudo" ]||[ $(id -u) -eq 0 ];then
local usesudo=""
else
local usesudo="sudo"
fi
case $package_manager in
apt)$usesudo apt update
$usesudo $install_command jq curl bc netcat-openbsd dnsutils iproute2
;;
dnf|yum)$usesudo $install_command epel-release
$usesudo $package_manager makecache
$usesudo $install_command jq curl bc nmap-ncat bind-utils iproute
;;
pacman)$usesudo pacman -Sy
$usesudo $install_command jq curl bc gnu-netcat bind-tools iproute2
;;
apk)$usesudo apk update
$usesudo $install_command jq curl bc netcat-openbsd grep bind-tools iproute2
;;
pkg)$usesudo $package_manager update
$usesudo $package_manager $install_command jq curl bc netcat dnsutils iproute
;;
brew)$install_command jq curl bc netcat bind
;;
zypper)$usesudo zypper refresh
$usesudo $install_command jq curl bc netcat bind-utils iproute2
;;
xbps)$usesudo xbps-install -Sy
$usesudo $install_command jq curl bc netcat bind-utils iproute2
esac
}
declare -A browsers=(
[Chrome]="145.0.0.0 144.0.0.0 143.0.0.0 142.0.0.0 141.0.0.0 140.0.0.0"
[Firefox]="147.0 146.0 145.0 144.0 143.0 142.0 141.0 140.0")
generate_random_user_agent(){
local browsers_keys=(${!browsers[@]})
local random_browser_index=$((RANDOM%${#browsers_keys[@]}))
local browser=${browsers_keys[random_browser_index]}
case $browser in
Chrome)local versions=(${browsers[Chrome]})
local version=${versions[RANDOM%${#versions[@]}]}
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$version Safari/537.36"
;;
Firefox)local versions=(${browsers[Firefox]})
local version=${versions[RANDOM%${#versions[@]}]}
UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:$version) Gecko/20100101 Firefox/$version"
esac
}
adapt_locale(){
local ifunicode=$(printf '\u2800')
[[ ${#ifunicode} -gt 3 ]]&&export LC_CTYPE=en_US.UTF-8 2>/dev/null
}
load_country_data() {
    local dataset='lukes/ISO-3166-Countries-with-Regional-Codes'
    local url
    for url in "https://raw.githubusercontent.com/$dataset/master/all/all.json" \
               "https://cdn.jsdelivr.net/gh/$dataset@master/all/all.json"; do
        if country_data=$(curl -fsL --max-time 10 "$url") &&
            jq -e '.[0] | has("alpha-2") and has("name") and has("region")' <<< "$country_data" >/dev/null 2>&1; then
            return 0
        fi
    done
    country_data='[]'
}
is_valid_ipv4(){
local ip=$1
if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]];then
IFS='.' read -r -a octets <<<"$ip"
for octet in "${octets[@]}";do
if ((octet<0||octet>255));then
IPV4work=0
return 1
fi
done
IPV4work=1
return 0
else
IPV4work=0
return 1
fi
}
is_private_ipv4(){
local ip_address=$1
if [[ -z $ip_address ]];then
return 0
fi
if [[ $ip_address =~ ^10\. ]]||[[ $ip_address =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]||[[ $ip_address =~ ^192\.168\. ]]||[[ $ip_address =~ ^127\. ]]||[[ $ip_address =~ ^0\. ]]||[[ $ip_address =~ ^22[4-9]\. ]]||[[ $ip_address =~ ^23[0-9]\. ]];then
return 0
fi
return 1
}
get_ipv4(){
local response
IPV4=""
local API_NET=("ipinfo.io/ip" "ip.sb" "ping0.cc" "icanhazip.com" "api64.ipify.org" "ifconfig.co" "ident.me")
for p in "${API_NET[@]}";do
response=$(curl "${CurlARG[@]}" -fs4 --max-time 2 "https://$p")
if [[ $? -eq 0 && $response =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];then
IPV4="$response"
break
fi
done
}
hide_ipv4(){
if [[ -n $1 ]];then
IFS='.' read -r -a ip_parts <<<"$1"
IPhide="${ip_parts[0]}.${ip_parts[1]}.*.*"
else
IPhide=""
fi
}
is_valid_ipv6(){
local ip=$1
if [[ $ip =~ ^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$ || $ip =~ ^([0-9a-fA-F]{1,4}:){1,7}:$ || $ip =~ ^:([0-9a-fA-F]{1,4}:){1,7}$ || $ip =~ ^([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}$ || $ip =~ ^([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}$ || $ip =~ ^([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}$ || $ip =~ ^([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}$ || $ip =~ ^([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}$ || $ip =~ ^[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})$ || $ip =~ ^:((:[0-9a-fA-F]{1,4}){1,7}|:)$ || $ip =~ ^fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}$ || $ip =~ ^::(ffff(:0{1,4}){0,1}:){0,1}(([0-9]{1,3}\.){3}[0-9]{1,3})$ || $ip =~ ^([0-9a-fA-F]{1,4}:){1,4}:(([0-9]{1,3}\.){3}[0-9]{1,3})$ ]];then
IPV6work=1
return 0
else
IPV6work=0
return 1
fi
}
is_private_ipv6(){
local address=$1
if [[ -z $address ]];then
return 0
fi
if [[ $address =~ ^fe80: ]]||[[ $address =~ ^fc00: ]]||[[ $address =~ ^fd00: ]]||[[ $address =~ ^2001:db8: ]]||[[ $address == ::1 ]]||[[ $address =~ ^::ffff: ]]||[[ $address =~ ^2002: ]]||[[ $address =~ ^2001: ]];then
return 0
fi
return 1
}
get_ipv6(){
local response
IPV6=""
local API_NET=("ip.sb" "ping0.cc" "icanhazip.com" "api64.ipify.org" "ifconfig.co" "ident.me")
for p in "${API_NET[@]}";do
response=$(curl "${CurlARG[@]}" -fs6 --max-time 2 "https://$p")
if [[ $? -eq 0 && $response =~ ^[0-9a-fA-F:]+$ && $response == *:* ]];then
IPV6="$response"
break
fi
done
}
hide_ipv6(){
if [[ -n $1 ]];then
local expanded_ip=$(echo "$1"|sed 's/::/:0000:0000:0000:0000:0000:0000:0000:0000:/g'|cut -d ':' -f1-8)
IFS=':' read -r -a ip_parts <<<"$expanded_ip"
while [ ${#ip_parts[@]} -lt 8 ];do
ip_parts+=(0000)
done
IPhide="${ip_parts[0]:-0}:${ip_parts[1]:-0}:${ip_parts[2]:-0}:*:*:*:*:*"
IPhide=$(echo "$IPhide"|sed 's/:0\{1,\}/:/g'|sed 's/::\+/:/g')
else
IPhide=""
fi
}
calculate_display_width(){
local string="$1"
local length=0
local char
for ((i=0; i<${#string}; i++));do
char=$(echo "$string"|od -An -N1 -tx1 -j $((i))|tr -d ' ')
if [ "$(printf '%d\n' 0x$char)" -gt 127 ];then
length=$((length+2))
i=$((i+1))
else
length=$((length+1))
fi
done
echo "$length"
}
calc_padding(){
local input_text="$1"
local total_width=$2
local title_length=$(calculate_display_width "$input_text")
local left_padding=$(((total_width-title_length)/2))
if [[ $left_padding -gt 0 ]];then
PADDING=$(printf '%*s' $left_padding)
else
PADDING=""
fi
}
generate_dms() {
    local decimal='^-?[0-9]+([.][0-9]+)?$'
    [[ $1 =~ $decimal && $2 =~ $decimal ]] || return 0
    LC_ALL=C awk -v lat="$1" -v lon="$2" '
        function dms(value, positive, negative,    direction, seconds) {
            direction = value < 0 ? negative : positive
            seconds = int((value < 0 ? -value : value) * 3600 + 0.5)
            return sprintf("%d°%d′%d″%s", int(seconds / 3600),
                int(seconds / 60) % 60, seconds % 60, direction)
        }
        BEGIN {
            if (lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180)
                print dms(lon, "E", "W") ", " dms(lat, "N", "S")
        }
    '
}
generate_googlemap_url() {
    printf 'https://www.google.com/maps?q=%s,%s\n' "$1" "$2"
}
db_maxmind(){
maxmind=()
local RESPONSE=$(curl "${CurlARG[@]}" -Ls -$1 -m 10 "https://ipinfo.check.place/$IP?lang=$YY")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
if [[ -z $RESPONSE ]];then
mode_lite=1
else
mode_lite=0
fi
maxmind[asn]=$(echo "$RESPONSE"|jq -r '.ASN.AutonomousSystemNumber')
maxmind[org]=$(echo "$RESPONSE"|jq -r '.ASN.AutonomousSystemOrganization')
maxmind[city]=$(echo "$RESPONSE"|jq -r '.City.Name')
maxmind[post]=$(echo "$RESPONSE"|jq -r '.City.PostalCode')
maxmind[lat]=$(echo "$RESPONSE"|jq -r '.City.Latitude')
maxmind[lon]=$(echo "$RESPONSE"|jq -r '.City.Longitude')
maxmind[continentcode]=$(echo "$RESPONSE"|jq -r '.City.Continent.Code')
maxmind[continent]=$(echo "$RESPONSE"|jq -r '.City.Continent.Name')
maxmind[citycountrycode]=$(echo "$RESPONSE"|jq -r '.City.Country.IsoCode')
maxmind[citycountry]=$(echo "$RESPONSE"|jq -r '.City.Country.Name')
maxmind[timezone]=$(echo "$RESPONSE"|jq -r '.City.Location.TimeZone')
maxmind[subcode]=$(echo "$RESPONSE"|jq -r 'if .City.Subdivisions | length > 0 then .City.Subdivisions[0].IsoCode else "N/A" end')
maxmind[sub]=$(echo "$RESPONSE"|jq -r 'if .City.Subdivisions | length > 0 then .City.Subdivisions[0].Name else "N/A" end')
maxmind[countrycode]=$(echo "$RESPONSE"|jq -r '.Country.IsoCode')
maxmind[country]=$(echo "$RESPONSE"|jq -r '.Country.Name')
maxmind[regcountrycode]=$(echo "$RESPONSE"|jq -r '.Country.RegisteredCountry.IsoCode')
maxmind[regcountry]=$(echo "$RESPONSE"|jq -r '.Country.RegisteredCountry.Name')
if [[ $YY != "en" ]];then
local backup_response=$(curl "${CurlARG[@]}" -s -$1 -m 10 "https://ipinfo.check.place/$IP?lang=en")
[[ ${maxmind[asn]} == "null" ]]&&maxmind[asn]=$(echo "$backup_response"|jq -r '.ASN.AutonomousSystemNumber')
[[ ${maxmind[org]} == "null" ]]&&maxmind[org]=$(echo "$backup_response"|jq -r '.ASN.AutonomousSystemOrganization')
[[ ${maxmind[city]} == "null" ]]&&maxmind[city]=$(echo "$backup_response"|jq -r '.City.Name')
[[ ${maxmind[post]} == "null" ]]&&maxmind[post]=$(echo "$backup_response"|jq -r '.City.PostalCode')
[[ ${maxmind[lat]} == "null" ]]&&maxmind[lat]=$(echo "$backup_response"|jq -r '.City.Latitude')
[[ ${maxmind[lon]} == "null" ]]&&maxmind[lon]=$(echo "$backup_response"|jq -r '.City.Longitude')
[[ ${maxmind[continentcode]} == "null" ]]&&maxmind[continentcode]=$(echo "$backup_response"|jq -r '.City.Continent.Code')
[[ ${maxmind[continent]} == "null" ]]&&maxmind[continent]=$(echo "$backup_response"|jq -r '.City.Continent.Name')
[[ ${maxmind[citycountrycode]} == "null" ]]&&maxmind[citycountrycode]=$(echo "$backup_response"|jq -r '.City.Country.IsoCode')
[[ ${maxmind[citycountry]} == "null" ]]&&maxmind[citycountry]=$(echo "$backup_response"|jq -r '.City.Country.Name')
[[ ${maxmind[timezone]} == "null" ]]&&maxmind[timezone]=$(echo "$backup_response"|jq -r '.City.Location.TimeZone')
[[ ${maxmind[subcode]} == "null" ]]&&maxmind[subcode]=$(echo "$backup_response"|jq -r 'if .City.Subdivisions | length > 0 then .City.Subdivisions[0].IsoCode else "N/A" end')
[[ ${maxmind[sub]} == "null" ]]&&maxmind[sub]=$(echo "$backup_response"|jq -r 'if .City.Subdivisions | length > 0 then .City.Subdivisions[0].Name else "N/A" end')
[[ ${maxmind[countrycode]} == "null" ]]&&maxmind[countrycode]=$(echo "$backup_response"|jq -r '.Country.IsoCode')
[[ ${maxmind[country]} == "null" ]]&&maxmind[country]=$(echo "$backup_response"|jq -r '.Country.Name')
[[ ${maxmind[regcountrycode]} == "null" ]]&&maxmind[regcountrycode]=$(echo "$backup_response"|jq -r '.Country.RegisteredCountry.IsoCode')
[[ ${maxmind[regcountry]} == "null" ]]&&maxmind[regcountry]=$(echo "$backup_response"|jq -r '.Country.RegisteredCountry.Name')
fi
maxmind[dms]=$(generate_dms "${maxmind[lat]}" "${maxmind[lon]}")
if [[ -n ${maxmind[dms]} ]];then
maxmind[map]=$(generate_googlemap_url "${maxmind[lat]}" "${maxmind[lon]}")
else
maxmind[dms]="null"
maxmind[map]="null"
fi
}
db_ipinfo(){
ipinfo=()
if [[ $IP == *:* ]];then
local RESPONSE=$(curl -Ls -m 10 "https://ipinfo.io/widget/demo/$IP")
else
local RESPONSE=$(curl "${CurlARG[@]}" -Ls -m 10 "https://ipinfo.io/widget/demo/$IP")
fi
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
ipinfo[usetype]=$(echo "$RESPONSE"|jq -r '.data.asn.type')
ipinfo[comtype]=$(echo "$RESPONSE"|jq -r '.data.company.type')
shopt -s nocasematch
case ${ipinfo[usetype]} in
"business")ipinfo[susetype]="${stype[business]}"
;;
"isp")ipinfo[susetype]="${stype[isp]}"
;;
"hosting")ipinfo[susetype]="${stype[hosting]}"
;;
"education")ipinfo[susetype]="${stype[education]}"
;;
*)ipinfo[susetype]="${stype[other]}"
esac
case ${ipinfo[comtype]} in
"business")ipinfo[scomtype]="${stype[business]}"
;;
"isp")ipinfo[scomtype]="${stype[isp]}"
;;
"hosting")ipinfo[scomtype]="${stype[hosting]}"
;;
"education")ipinfo[scomtype]="${stype[education]}"
;;
*)ipinfo[scomtype]="${stype[other]}"
esac
shopt -u nocasematch
ipinfo[countrycode]=$(echo "$RESPONSE"|jq -r '.data.country')
ipinfo[proxy]=$(echo "$RESPONSE"|jq -r '.data.privacy.proxy')
ipinfo[tor]=$(echo "$RESPONSE"|jq -r '.data.privacy.tor')
ipinfo[vpn]=$(echo "$RESPONSE"|jq -r '.data.privacy.vpn')
ipinfo[server]=$(echo "$RESPONSE"|jq -r '.data.privacy.hosting')
ipinfo[asn]=$(echo "$RESPONSE"|jq -r '.data.asn.asn'|sed 's/^AS//')
ipinfo[org]=$(echo "$RESPONSE"|jq -r '.data.asn.name')
ipinfo[city]=$(echo "$RESPONSE"|jq -r '.data.city')
ipinfo[post]=$(echo "$RESPONSE"|jq -r '.data.postal')
ipinfo[sub]=$(echo "$RESPONSE"|jq -r '.data.region')
ipinfo[timezone]=$(echo "$RESPONSE"|jq -r '.data.timezone')
local coordinates lat lon
coordinates=$(jq -r '.data.loc // empty' <<< "$RESPONSE")
IFS=, read -r lat lon <<< "$coordinates"
ipinfo[lat]=${lat:-null}
ipinfo[lon]=${lon:-null}
ipinfo[countrycode]=$(echo "$RESPONSE"|jq -r '.data.country')
ipinfo[country]=$(jq --arg code "${ipinfo[countrycode]}" -r '.[] | select(.["alpha-2"] == $code) | .name' <<< "$country_data")
ipinfo[continent]=$(jq --arg code "${ipinfo[countrycode]}" -r '.[] | select(.["alpha-2"] == $code) | .region' <<< "$country_data")
ipinfo[regcountrycode]=$(echo "$RESPONSE"|jq -r '.data.abuse.country')
ipinfo[regcountry]=$(jq --arg code "${ipinfo[regcountrycode]}" -r '.[] | select(.["alpha-2"] == $code) | .name' <<< "$country_data")
ipinfo[dms]=$(generate_dms "${ipinfo[lat]}" "${ipinfo[lon]}")
if [[ -n ${ipinfo[dms]} ]];then
ipinfo[map]=$(generate_googlemap_url "${ipinfo[lat]}" "${ipinfo[lon]}")
else
ipinfo[dms]="null"
ipinfo[map]="null"
fi
}
fill_basic_location() {
    local key
    uses_ipinfo_location=0
    [[ $mode_lite -eq 0 && ${ipinfo[countrycode]} =~ ^[A-Z]{2}$ ]] || return 0
    if [[ ${maxmind[countrycode]} =~ ^[A-Z]{2}$ && ${maxmind[countrycode]} != "${ipinfo[countrycode]}" ]]; then
        return 0
    fi

    if [[ ( -z ${maxmind[dms]} || ${maxmind[dms]} == null ) &&
        -n ${ipinfo[dms]} && ${ipinfo[dms]} != null ]]; then
        for key in lat lon dms map; do
            maxmind[$key]=${ipinfo[$key]}
        done
        uses_ipinfo_location=1
    fi
    if [[ ( -z ${maxmind[city]} || ${maxmind[city]} == null || ${maxmind[city]} == N/A ) &&
        -n ${ipinfo[city]} && ${ipinfo[city]} != null && ${ipinfo[city]} != N/A ]]; then
        for key in city sub post; do
            maxmind[$key]=${ipinfo[$key]}
        done
        maxmind[subcode]=null
        uses_ipinfo_location=1
    fi
}
db_scamalytics(){
scamalytics=()
local RESPONSE=$(curl "${CurlARG[@]}" -sL -$1 -m 10 "https://ipinfo.check.place/$IP?db=scamalytics")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
scamalytics[countrycode]=$(echo "$RESPONSE"|jq -r '.external_datasources.maxmind_geolite2.ip_country_code')
scamalytics[proxy]=$(echo "$RESPONSE"|jq -r '.external_datasources.firehol.is_proxy')
scamalytics[tor]=$(echo "$RESPONSE"|jq -r '.external_datasources.x4bnet.is_tor')
scamalytics[vpn]=$(echo "$RESPONSE"|jq -r '.scamalytics.scamalytics_proxy.is_vpn')
scamalytics[server]=$(echo "$RESPONSE"|jq -r '.scamalytics.scamalytics_proxy.is_datacenter')
scamalytics[abuser]=$(echo "$RESPONSE"|jq -r '.scamalytics.is_blacklisted_external')
scamalytics[robot1]=$(echo "$RESPONSE"|jq -r '.external_datasources.x4bnet.is_blacklisted_spambot')
scamalytics[robot2]=$(echo "$RESPONSE"|jq -r '.external_datasources.x4bnet.is_bot_operamini')
scamalytics[robot3]=$(echo "$RESPONSE"|jq -r '.external_datasources.x4bnet.is_bot_semrush')
[[ ${scamalytics[robot1]} == "true" || ${scamalytics[robot2]} == "true" || ${scamalytics[robot3]} == "true" ]]&&scamalytics[robot]="true"
[[ ${scamalytics[robot1]} == "false" && ${scamalytics[robot2]} == "false" && ${scamalytics[robot3]} == "false" ]]&&scamalytics[robot]="false"
scamalytics[score]=$(echo "$RESPONSE"|jq -r '.scamalytics.scamalytics_score')
if [[ ${scamalytics[score]} -lt 20 ]];then
scamalytics[risk]="${sscore[low]}"
elif [[ ${scamalytics[score]} -lt 60 ]];then
scamalytics[risk]="${sscore[medium]}"
elif [[ ${scamalytics[score]} -lt 90 ]];then
scamalytics[risk]="${sscore[high]}"
elif [[ ${scamalytics[score]} -ge 90 ]];then
scamalytics[risk]="${sscore[veryhigh]}"
fi
}
db_ipregistry(){
ipregistry=()
local tmpgo="sb69ksjcajfs4c"
local REGISTRY_HTML
REGISTRY_HTML=$(curl "${CurlARG[@]}" -sL -$1 -m 10 -H "User-Agent: $UA_Browser" "https://ipregistry.co")
if [[ -n $REGISTRY_HTML ]];then
if [[ $REGISTRY_HTML =~ apiKey=\"([a-zA-Z0-9]+)\" ]];then
tmpgo="${BASH_REMATCH[1]}"
fi
fi
local RESPONSE
RESPONSE=$(curl "${CurlARG[@]}" -sS -$1 --compressed -m 10 \
-H "authority: api.ipregistry.co" \
-H "origin: https://ipregistry.co" \
-H "referer: https://ipregistry.co/" \
-H "User-Agent: $UA_Browser" \
"https://api.ipregistry.co/$IP?hostname=true&key=$tmpgo")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
ipregistry[usetype]=$(echo "$RESPONSE"|jq -r '.connection.type')
ipregistry[comtype]=$(echo "$RESPONSE"|jq -r '.company.type')
shopt -s nocasematch
case ${ipregistry[usetype]} in
"business")ipregistry[susetype]="${stype[business]}"
;;
"isp")ipregistry[susetype]="${stype[isp]}"
;;
"hosting")ipregistry[susetype]="${stype[hosting]}"
;;
"education")ipregistry[susetype]="${stype[education]}"
;;
"government")ipregistry[susetype]="${stype[government]}"
;;
*)ipregistry[susetype]="${stype[other]}"
esac
case ${ipregistry[comtype]} in
"business")ipregistry[scomtype]="${stype[business]}"
;;
"isp")ipregistry[scomtype]="${stype[isp]}"
;;
"hosting")ipregistry[scomtype]="${stype[hosting]}"
;;
"education")ipregistry[scomtype]="${stype[education]}"
;;
"government")ipregistry[scomtype]="${stype[government]}"
;;
*)ipregistry[scomtype]="${stype[other]}"
esac
shopt -u nocasematch
ipregistry[countrycode]=$(echo "$RESPONSE"|jq -r '.location.country.code')
ipregistry[proxy]=$(echo "$RESPONSE"|jq -r '.security.is_proxy')
ipregistry[tor1]=$(echo "$RESPONSE"|jq -r '.security.is_tor')
ipregistry[tor2]=$(echo "$RESPONSE"|jq -r '.security.is_tor_exit')
[[ ${ipregistry[tor1]} == "true" || ${ipregistry[tor2]} == "true" ]]&&ipregistry[tor]="true"
[[ ${ipregistry[tor1]} == "false" && ${ipregistry[tor2]} == "false" ]]&&ipregistry[tor]="false"
ipregistry[vpn]=$(echo "$RESPONSE"|jq -r '.security.is_vpn')
ipregistry[server]=$(echo "$RESPONSE"|jq -r '.security.is_cloud_provider')
ipregistry[abuser]=$(echo "$RESPONSE"|jq -r '.security.is_abuser')
}
db_ipapi(){
ipapi=()
local RESPONSE=$(curl "${CurlARG[@]}" -sL -$1 -m 10 "https://ipinfo.check.place/$IP?db=ipapi")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
[[ -z $RESPONSE ]]&&return 1
ipapi[usetype]=$(echo "$RESPONSE"|jq -r '.asn.type')
ipapi[comtype]=$(echo "$RESPONSE"|jq -r '.company.type')
shopt -s nocasematch
case ${ipapi[usetype]} in
"business")ipapi[susetype]="${stype[business]}"
;;
"isp")ipapi[susetype]="${stype[isp]}"
;;
"hosting")ipapi[susetype]="${stype[hosting]}"
;;
"education")ipapi[susetype]="${stype[education]}"
;;
"government")ipapi[susetype]="${stype[government]}"
;;
"banking")ipapi[susetype]="${stype[banking]}"
;;
*)ipapi[susetype]="${stype[other]}"
esac
case ${ipapi[comtype]} in
"business")ipapi[scomtype]="${stype[business]}"
;;
"isp")ipapi[scomtype]="${stype[isp]}"
;;
"hosting")ipapi[scomtype]="${stype[hosting]}"
;;
"education")ipapi[scomtype]="${stype[education]}"
;;
"government")ipapi[scomtype]="${stype[government]}"
;;
"banking")ipapi[scomtype]="${stype[banking]}"
;;
*)ipapi[scomtype]="${stype[other]}"
esac
ipapi[scoretext]=$(echo "$RESPONSE"|jq -r '.company.abuser_score')
ipapi[scorenum]=$(echo "${ipapi[scoretext]}"|awk '{print $1}')
ipapi[risktext]=$(echo "${ipapi[scoretext]}"|awk -F'[()]' '{print $2}')
[[ ${ipapi[scorenum]} =~ ^[0-9]+([.][0-9]+)?$ ]] &&
    ipapi[score]=$(awk -v score="${ipapi[scorenum]}" 'BEGIN { printf "%.2f%%", score * 100 }')
case ${ipapi[risktext]} in
"Very Low")ipapi[risk]="${sscore[verylow]}"
;;
"Low")ipapi[risk]="${sscore[low]}"
;;
"Elevated")ipapi[risk]="${sscore[elevated]}"
;;
"High")ipapi[risk]="${sscore[high]}"
;;
"Very High")ipapi[risk]="${sscore[veryhigh]}"
esac
shopt -u nocasematch
ipapi[countrycode]=$(echo "$RESPONSE"|jq -r '.location.country_code')
ipapi[proxy]=$(echo "$RESPONSE"|jq -r '.is_proxy')
ipapi[tor]=$(echo "$RESPONSE"|jq -r '.is_tor')
ipapi[vpn]=$(echo "$RESPONSE"|jq -r '.is_vpn')
ipapi[server]=$(echo "$RESPONSE"|jq -r '.is_datacenter')
ipapi[abuser]=$(echo "$RESPONSE"|jq -r '.is_abuser')
ipapi[robot]=$(echo "$RESPONSE"|jq -r '.is_crawler')
}
db_abuseipdb(){
abuseipdb=()
local RESPONSE=$(curl "${CurlARG[@]}" -sL -$1 -m 10 "https://ipinfo.check.place/$IP?db=abuseipdb")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
abuseipdb[usetype]=$(echo "$RESPONSE"|jq -r '.data.usageType')
shopt -s nocasematch
case ${abuseipdb[usetype]} in
"Commercial")abuseipdb[susetype]="${stype[business]}"
;;
"Data Center/Web Hosting/Transit")abuseipdb[susetype]="${stype[hosting]}"
;;
"University/College/School")abuseipdb[susetype]="${stype[education]}"
;;
"Government")abuseipdb[susetype]="${stype[government]}"
;;
"banking")abuseipdb[susetype]="${stype[banking]}"
;;
"Organization")abuseipdb[susetype]="${stype[organization]}"
;;
"Military")abuseipdb[susetype]="${stype[military]}"
;;
"Library")abuseipdb[susetype]="${stype[library]}"
;;
"Content Delivery Network")abuseipdb[susetype]="${stype[cdn]}"
;;
"Fixed Line ISP")abuseipdb[susetype]="${stype[lineisp]}"
;;
"Mobile ISP")abuseipdb[susetype]="${stype[mobile]}"
;;
"Search Engine Spider")abuseipdb[susetype]="${stype[spider]}"
;;
"Reserved")abuseipdb[susetype]="${stype[reserved]}"
;;
*)abuseipdb[susetype]="${stype[other]}"
esac
shopt -u nocasematch
abuseipdb[score]=$(echo "$RESPONSE"|jq -r '.data.abuseConfidenceScore')
if [[ ${abuseipdb[score]} -lt 25 ]];then
abuseipdb[risk]="${sscore[low]}"
elif [[ ${abuseipdb[score]} -lt 75 ]];then
abuseipdb[risk]="${sscore[high]}"
elif [[ ${abuseipdb[score]} -ge 75 ]];then
abuseipdb[risk]="${sscore[dos]}"
fi
}
db_ip2location(){
ip2location=()
local RESPONSE=$(curl "${CurlARG[@]}" -sL -$1 -m 10 "https://ipinfo.check.place/$IP?db=ip2location")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
ip2location[usetype]=$(echo "$RESPONSE"|jq -r '.usage_type')
ip2location[comtype]=$(echo "$RESPONSE"|jq -r '.as_info.as_usage_type')
shopt -s nocasematch
local first_use="${ip2location[usetype]%%/*}"
case $first_use in
"COM")ip2location[susetype]="${stype[business]}"
;;
"DCH")ip2location[susetype]="${stype[hosting]}"
;;
"EDU")ip2location[susetype]="${stype[education]}"
;;
"GOV")ip2location[susetype]="${stype[government]}"
;;
"ORG")ip2location[susetype]="${stype[organization]}"
;;
"MIL")ip2location[susetype]="${stype[military]}"
;;
"LIB")ip2location[susetype]="${stype[library]}"
;;
"CDN")ip2location[susetype]="${stype[cdn]}"
;;
"ISP")ip2location[susetype]="${stype[lineisp]}"
;;
"MOB")ip2location[susetype]="${stype[mobile]}"
;;
"SES")ip2location[susetype]="${stype[spider]}"
;;
"RSV")ip2location[susetype]="${stype[reserved]}"
;;
*)ip2location[susetype]="${stype[other]}"
esac
first_use="${ip2location[comtype]%%/*}"
case $first_use in
"COM")ip2location[scomtype]="${stype[business]}"
;;
"DCH")ip2location[scomtype]="${stype[hosting]}"
;;
"EDU")ip2location[scomtype]="${stype[education]}"
;;
"GOV")ip2location[scomtype]="${stype[government]}"
;;
"ORG")ip2location[scomtype]="${stype[organization]}"
;;
"MIL")ip2location[scomtype]="${stype[military]}"
;;
"LIB")ip2location[scomtype]="${stype[library]}"
;;
"CDN")ip2location[scomtype]="${stype[cdn]}"
;;
"ISP")ip2location[scomtype]="${stype[lineisp]}"
;;
"MOB")ip2location[scomtype]="${stype[mobile]}"
;;
"SES")ip2location[scomtype]="${stype[spider]}"
;;
"RSV")ip2location[scomtype]="${stype[reserved]}"
;;
*)ip2location[scomtype]="${stype[other]}"
esac
shopt -u nocasematch
ip2location[countrycode]=$(echo "$RESPONSE"|jq -r '.country_code')
ip2location[proxy0]=$(echo "$RESPONSE"|jq -r '.is_proxy')
ip2location[proxy1]=$(echo "$RESPONSE"|jq -r '.proxy.is_public_proxy')
ip2location[proxy2]=$(echo "$RESPONSE"|jq -r '.proxy.is_web_proxy')
[[ ${ip2location[proxy0]} == "true" || ${ip2location[proxy1]} == "true" || ${ip2location[proxy2]} == "true" ]]&&ip2location[proxy]="true"
[[ ${ip2location[proxy0]} == "false" && ${ip2location[proxy1]} == "false" && ${ip2location[proxy2]} == "false" ]]&&ip2location[proxy]="false"
ip2location[tor]=$(echo "$RESPONSE"|jq -r '.proxy.is_tor')
ip2location[vpn]=$(echo "$RESPONSE"|jq -r '.proxy.is_vpn')
ip2location[server]=$(echo "$RESPONSE"|jq -r '.proxy.is_data_center')
ip2location[abuser]=$(echo "$RESPONSE"|jq -r '.proxy.is_spammer')
ip2location[robot1]=$(echo "$RESPONSE"|jq -r '.proxy.is_web_crawler')
ip2location[robot2]=$(echo "$RESPONSE"|jq -r '.proxy.is_scanner')
ip2location[robot3]=$(echo "$RESPONSE"|jq -r '.proxy.is_botnet')
[[ ${ip2location[robot1]} == "true" || ${ip2location[robot2]} == "true" || ${ip2location[robot3]} == "true" ]]&&ip2location[robot]="true"
[[ ${ip2location[robot1]} == "false" && ${ip2location[robot2]} == "false" && ${ip2location[robot3]} == "false" ]]&&ip2location[robot]="false"
ip2location[score]=$(echo "$RESPONSE"|jq -r '.fraud_score')
if [[ ${ip2location[score]} -lt 33 ]];then
ip2location[risk]="${sscore[low]}"
elif [[ ${ip2location[score]} -lt 66 ]];then
ip2location[risk]="${sscore[medium]}"
elif [[ ${ip2location[score]} -ge 66 ]];then
ip2location[risk]="${sscore[high]}"
fi
}
db_dbip(){
dbip=()
local -a curl_args=("${CurlARG[@]}")
if [[ $IP == *:* ]];then
curl_args=()
fi
local RESPONSE=$(curl "${curl_args[@]}" -sL -m 10 -H 'accept: */*' -H 'accept-language: en-US,en;q=0.9' -H 'content-type: text/html;charset=UTF-8' -H 'dnt: 1' -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36' "https://db-ip.com/api/core/")
local tmpurl=$(echo "$RESPONSE"|sed -n 's/.*data-api-key="\([^"]*\)".*/\1/p'|head -n 1)
RESPONSE=$(curl "${curl_args[@]}" -sL -m 10 -H 'accept: */*' -H 'accept-language: en-US,en;q=0.9' -H 'content-type: text/plain;charset=UTF-8' -H 'dnt: 1' -H 'origin: https://db-ip.com' -H 'priority: u=1, i' -H 'referer: https://db-ip.com/' -H 'sec-ch-ua: "Not=A?Brand";v="99", "Google Chrome";v="151", "Chromium";v="151"' -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-dest: empty' -H 'sec-fetch-mode: cors' -H 'sec-fetch-site: same-site' -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36' --data-raw '[["11.49","EUR"],["139.90","EUR"],["699.90","EUR"]]' "https://api.db-ip.com/v2/$tmpurl/self?convertCurrencies")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
dbip[robot]=$(echo "$RESPONSE"|jq -r '.isCrawler')
dbip[proxy]=$(echo "$RESPONSE"|jq -r '.isProxy')
dbip[risktext]=$(echo "$RESPONSE"|jq -r '.threatLevel')
dbip[countrycode]=$(echo "$RESPONSE"|jq -r '.countryCode')
shopt -s nocasematch
case ${dbip[risktext]} in
"low")dbip[risk]="${sscore[low]}"
dbip[score]=0
;;
"medium")dbip[risk]="${sscore[medium]}"
dbip[score]=50
;;
"high")dbip[risk]="${sscore[high]}"
dbip[score]=100
esac
shopt -u nocasematch
}
db_ipdata(){
ipdata=()
local RESPONSE=$(curl "${CurlARG[@]}" -sL -$1 -m 10 "https://ipinfo.check.place/$IP?db=ipdata")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
ipdata[countrycode]=$(echo "$RESPONSE"|jq -r '.country_code')
ipdata[proxy]=$(echo "$RESPONSE"|jq -r '.threat.is_proxy')
ipdata[tor]=$(echo "$RESPONSE"|jq -r '.threat.is_tor')
ipdata[server]=$(echo "$RESPONSE"|jq -r '.threat.is_datacenter')
ipdata[abuser1]=$(echo "$RESPONSE"|jq -r '.threat.is_threat')
ipdata[abuser2]=$(echo "$RESPONSE"|jq -r '.threat.is_known_abuser')
ipdata[abuser3]=$(echo "$RESPONSE"|jq -r '.threat.is_known_attacker')
[[ ${ipdata[abuser1]} == "true" || ${ipdata[abuser2]} == "true" || ${ipdata[abuser3]} == "true" ]]&&ipdata[abuser]="true"
[[ ${ipdata[abuser1]} == "false" && ${ipdata[abuser2]} == "false" && ${ipdata[abuser3]} == "false" ]]&&ipdata[abuser]="false"
}
db_ipqs(){
ipqs=()
local RESPONSE=$(curl "${CurlARG[@]}" -sL -$1 -m 10 "https://ipinfo.check.place/$IP?db=ipqualityscore")
echo "$RESPONSE"|jq . >/dev/null 2>&1||RESPONSE=""
ipqs[score]=$(echo "$RESPONSE"|jq -r '.fraud_score')
if [[ ${ipqs[score]} -lt 75 ]];then
ipqs[risk]="${sscore[low]}"
elif [[ ${ipqs[score]} -lt 85 ]];then
ipqs[risk]="${sscore[suspicious]}"
elif [[ ${ipqs[score]} -lt 90 ]];then
ipqs[risk]="${sscore[risky]}"
elif [[ ${ipqs[score]} -ge 90 ]];then
ipqs[risk]="${sscore[highrisk]}"
fi
ipqs[countrycode]=$(echo "$RESPONSE"|jq -r '.country_code')
ipqs[proxy]=$(echo "$RESPONSE"|jq -r '.proxy')
ipqs[tor]=$(echo "$RESPONSE"|jq -r '.tor')
ipqs[vpn]=$(echo "$RESPONSE"|jq -r '.vpn')
ipqs[abuser]=$(echo "$RESPONSE"|jq -r '.recent_abuse')
ipqs[robot]=$(echo "$RESPONSE"|jq -r '.bot_status')
}
function check_ip_valide(){
local IPPattern='^(\<([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\>\.){3}\<([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\>$'
IP="$1"
if [[ $IP =~ $IPPattern ]];then
return 0
else
return 1
fi
}
function calc_ip_net(){
sip="$1"
snetmask="$2"
check_ip_valide "$sip"
if [ $? -ne 0 ];then
echo ""
return 1
fi
local ipFIELD1=$(echo "$sip"|cut -d. -f1)
local ipFIELD2=$(echo "$sip"|cut -d. -f2)
local ipFIELD3=$(echo "$sip"|cut -d. -f3)
local ipFIELD4=$(echo "$sip"|cut -d. -f4)
local netmaskFIELD1=$(echo "$snetmask"|cut -d. -f1)
local netmaskFIELD2=$(echo "$snetmask"|cut -d. -f2)
local netmaskFIELD3=$(echo "$snetmask"|cut -d. -f3)
local netmaskFIELD4=$(echo "$snetmask"|cut -d. -f4)
local tmpret1=$((ipFIELD1&netmaskFIELD1))
local tmpret2=$((ipFIELD2&netmaskFIELD2))
local tmpret3=$((ipFIELD3&netmaskFIELD3))
local tmpret4=$((ipFIELD4&netmaskFIELD4))
echo "$tmpret1.$tmpret2.$tmpret3.$tmpret4"
}
function Check_DNS_IP(){
if [ "$1" != "${1#*[0-9].[0-9]}" ];then
if [ "$(calc_ip_net "$1" 255.0.0.0)" == "10.0.0.0" ];then
echo 0
elif [ "$(calc_ip_net "$1" 255.240.0.0)" == "172.16.0.0" ];then
echo 0
elif [ "$(calc_ip_net "$1" 255.255.0.0)" == "169.254.0.0" ];then
echo 0
elif [ "$(calc_ip_net "$1" 255.255.0.0)" == "192.168.0.0" ];then
echo 0
elif [ "$(calc_ip_net "$1" 255.255.255.0)" == "$(calc_ip_net "$2" 255.255.255.0)" ];then
echo 0
else
echo 1
fi
elif [ "$1" != "${1#*[0-9a-fA-F]:*}" ];then
if [ "${1:0:3}" == "fe8" ];then
echo 0
elif [ "${1:0:3}" == "FE8" ];then
echo 0
elif [ "${1:0:2}" == "fc" ];then
echo 0
elif [ "${1:0:2}" == "FC" ];then
echo 0
elif [ "${1:0:2}" == "fd" ];then
echo 0
elif [ "${1:0:2}" == "FD" ];then
echo 0
elif [ "${1:0:2}" == "ff" ];then
echo 0
elif [ "${1:0:2}" == "FF" ];then
echo 0
else
echo 1
fi
else
echo 1
fi
}
function Check_DNS_1(){
local resultdns=$(nslookup $1)
local resultinlines=(${resultdns//$'\n'/ })
for i in ${resultinlines[*]};do
if [[ $i == "Name:" ]];then
local resultdnsindex=$((resultindex+3))
break
fi
local resultindex=$((resultindex+1))
done
echo $(Check_DNS_IP ${resultinlines[$resultdnsindex]} ${resultinlines[1]})
}
function Check_DNS_2(){
local resultdnstext=$(dig $1|grep "ANSWER:")
local resultdnstext=${resultdnstext#*"ANSWER: "}
local resultdnstext=${resultdnstext%", AUTHORITY:"*}
if [ "$resultdnstext" == "0" ]||[ "$resultdnstext" == "1" ]||[ "$resultdnstext" == "2" ];then
echo 0
else
echo 1
fi
}
function Check_DNS_3(){
local resultdnstext=$(dig "test$RANDOM$RANDOM.$1"|grep "ANSWER:")
local resultdnstext=${resultdnstext#*"ANSWER: "}
local resultdnstext=${resultdnstext%", AUTHORITY:"*}
if [ "$resultdnstext" == "0" ]||[ -z "$resultdnstext" ];then
echo 1
else
echo 0
fi
}
function Get_Unlock_Type(){
while [ $# -ne 0 ];do
if [ "$1" = "0" ];then
echo "${smedia[dns]}"
return
fi
shift
done
echo "${smedia[native]}"
}
function MediaUnlockTest_TikTok(){
tiktok=()
local checkunlockurl="tiktok.com"
local result1=$(Check_DNS_1 $checkunlockurl)
local result3=$(Check_DNS_3 $checkunlockurl)
local resultunlocktype=$(Get_Unlock_Type $result1 $result3)
local Ftmpresult=$(curl "${CurlARG[@]}" -$1 --user-agent "$UA_Browser" -sL -m 10 "https://www.tiktok.com/")
[[ $Ftmpresult == *"Please wait..."* ]]&&Ftmpresult=$(curl "${CurlARG[@]}" --user-agent "$UA_Browser" -sL -m 10 "https://www.tiktok.com/explore")
if [[ $Ftmpresult == "curl"* ]];then
tiktok[ustatus]="${smedia[no]}"
tiktok[uregion]="${smedia[nodata]}"
tiktok[utype]="${smedia[nodata]}"
return
fi
local FRegion=$(echo $Ftmpresult|grep '"region":'|sed 's/.*"region"//'|cut -f2 -d'"')
if [ -n "$FRegion" ];then
tiktok[ustatus]="${smedia[yes]}"
local ttpadding=$((7-${#FRegion}))
local ttleft=$((ttpadding/2))
local ttright=$((ttpadding-ttleft))
tiktok[uregion]="$(printf "%*s%s%*s" "$ttleft" "" "[$FRegion]" "$ttright" "")"
tiktok[utype]="$resultunlocktype"
return
fi
local STmpresult=$(curl "${CurlARG[@]}" -$1 --user-agent "$UA_Browser" -sL -m 10 -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9" -H "Accept-Encoding: gzip" -H "Accept-Language: en" "https://www.tiktok.com"|gunzip 2>/dev/null)
[[ $Ftmpresult == *"Please wait..."* ]]&&STmpresult=$(curl "${CurlARG[@]}" --user-agent "$UA_Browser" -sL -m 10 -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9" -H "Accept-Encoding: gzip" -H "Accept-Language: en" "https://www.tiktok.com/explore"|gunzip 2>/dev/null)
local SRegion=$(echo $STmpresult|grep '"region":'|sed 's/.*"region"//'|cut -f2 -d'"')
if [ -n "$SRegion" ];then
tiktok[ustatus]="${smedia[idc]}"
local ttWidth=7
local ttpadding=$((7-${#SRegion}))
local ttleft=$((ttpadding/2))
local ttright=$((ttpadding-ttleft))
tiktok[uregion]="$(printf "%*s%s%*s" "$ttleft" "" "[$SRegion]" "$ttright" "")"
tiktok[utype]="$resultunlocktype"
return
else
tiktok[ustatus]="${smedia[bad]}"
tiktok[uregion]="${smedia[nodata]}"
tiktok[utype]="${smedia[nodata]}"
return
fi
}
function MediaUnlockTest_DisneyPlus(){
disney=()
disney[ustatus]="${smedia[bad]}"
disney[uregion]="${smedia[nodata]}"
disney[utype]="${smedia[nodata]}"
local checkunlockurl="disneyplus.com"
local result1=$(Check_DNS_1 $checkunlockurl)
local result3=$(Check_DNS_3 $checkunlockurl)
local resultunlocktype=$(Get_Unlock_Type $result1 $result3)
local PreAssertion=$(curl "${CurlARG[@]}" -$1 --user-agent "$UA_Browser" -s --max-time 10 -X POST "https://disney.api.edge.bamgrid.com/devices" -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -H "content-type: application/json; charset=UTF-8" -d '{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","attributes":{}}' 2>&1)
local assertion TokenContent refreshToken disneycontent
assertion=$(jq -er '.assertion | strings | select(length > 0)' <<< "$PreAssertion" 2>/dev/null) || return 0
TokenContent=$(curl "${CurlARG[@]}" -$1 --user-agent "$UA_Browser" -s --max-time 10 -X POST "https://disney.api.edge.bamgrid.com/token" \
    -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" \
    --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:token-exchange' \
    -d 'latitude=0&longitude=0&platform=browser' --data-urlencode "subject_token=$assertion" \
    --data-urlencode 'subject_token_type=urn:bamtech:params:oauth:token-type:device' 2>&1)
if [[ $TokenContent == *'403 ERROR'* ]] || jq -e '.error_description == "forbidden-location"' <<< "$TokenContent" >/dev/null 2>&1; then
disney[ustatus]="${smedia[no]}"
return
fi
refreshToken=$(jq -er '.refresh_token | strings | select(length > 0)' <<< "$TokenContent" 2>/dev/null) || return 0
disneycontent=$(jq -cn --arg token "$refreshToken" '{
    query: "mutation refreshToken($input: RefreshTokenInput!) { refreshToken(refreshToken: $input) { activeSession { sessionId } } }",
    variables: {input: {refreshToken: $token}}
}')
local tmpresult=$(curl "${CurlARG[@]}" -$1 --user-agent "$UA_Browser" -X POST -sSL --max-time 10 "https://disney.api.edge.bamgrid.com/graph/v1/device/graphql" -H "authorization: ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "$disneycontent" 2>&1)
if ! (echo "$tmpresult"|jq . >/dev/null 2>&1);then
disney[ustatus]="${smedia[bad]}"
disney[uregion]="${smedia[nodata]}"
disney[utype]="${smedia[nodata]}"
return
fi
local previewcheck=$(curl "${CurlARG[@]}" -$1 -s -o /dev/null -L --max-time 10 -w '%{url_effective}\n' "https://disneyplus.com"|grep preview)
local isUnavailable=$(echo $previewcheck|grep 'unavailable')
local region=$(echo $tmpresult|jq -r '.extensions.sdk.session.location.countryCode')
local inSupportedLocation=$(echo $tmpresult|jq -r '.extensions.sdk.session.inSupportedLocation')
if [[ $region == "JP" ]];then
disney[ustatus]="${smedia[yes]}"
disney[uregion]="  [JP]   "
disney[utype]="$resultunlocktype"
return
elif [ -n "$region" ]&&[[ $inSupportedLocation == "false" ]]&&[ -z "$isUnavailable" ];then
disney[ustatus]="${smedia[pending]}"
disney[uregion]="  [$region]   "
disney[utype]="$resultunlocktype"
return
elif [ -n "$region" ]&&[ -n "$isUnavailable" ];then
disney[ustatus]="${smedia[no]}"
disney[uregion]="${smedia[nodata]}"
disney[utype]="${smedia[nodata]}"
return
elif [ -n "$region" ]&&[[ $inSupportedLocation == "true" ]];then
disney[ustatus]="${smedia[yes]}"
disney[uregion]="  [$region]   "
disney[utype]="$resultunlocktype"
return
elif [ -z "$region" ];then
disney[ustatus]="${smedia[no]}"
disney[uregion]="${smedia[nodata]}"
disney[utype]="${smedia[nodata]}"
return
else
disney[ustatus]="${smedia[bad]}"
disney[uregion]="${smedia[nodata]}"
disney[utype]="${smedia[nodata]}"
return
fi
}
fetch_media_page() {
    local family=$1 url=$2
    shift 2
    curl "${CurlARG[@]}" "-$family" -sL --compressed --proto-redir '=https' \
        --max-redirs 5 --connect-timeout 4 --max-time 10 -H 'Accept-Language: en' \
        --write-out '\n%{http_code}\t%{url_effective}\t%{remote_ip}' "$@" "$url"
}

netflix_title_probe() {
    local family=$1 title=$2
    shift 2
    local response body code url peer status region=-
    local country_pattern='"requestCountry"[[:space:]]*:[[:space:]]*\{[^}]*"id"[[:space:]]*:[[:space:]]*"([A-Z]{2})"'
    local title_pattern="\"videoId\"[[:space:]]*:[[:space:]]*$title[[:space:]]*[,}]"
    local locale_pattern='^https://www\.netflix\.com/([a-z]{2})(-[a-zA-Z-]+)?/title/'

    response=$(fetch_media_page "$family" "https://www.netflix.com/title/$title" \
        --user-agent "$UA_Browser" "$@") || return 1
    IFS=$'\t' read -r code url peer <<< "${response##*$'\n'}"
    [[ $url == https://www.netflix.com/* ]] || return 1
    body=${response%$'\n'*}

    case $code in
        200)
            if [[ ${url%%\?*} == */title/"$title" && $body =~ $title_pattern ]]; then
                status=available
            elif [[ $body == *'>Oh no!<'* ]]; then
                status=unavailable
            else
                return 1
            fi
            ;;
        404|410) status=unavailable ;;
        403|451) status=blocked ;;
        *) return 1 ;;
    esac
    if [[ $body =~ $country_pattern ]]; then
        region=${BASH_REMATCH[1]}
    elif [[ $url =~ $locale_pattern ]]; then
        region=${BASH_REMATCH[1]^^}
    fi
    printf '%s %s %s\n' "$status" "$region" "${peer:--}"
}

media_public_address() {
    local family=$1 hostname=$2 record_type=1 response address
    # A forward proxy may resolve the service name itself.
    if [[ -n ${HTTPS_PROXY:-${https_proxy:-${ALL_PROXY:-${all_proxy:-}}}} ]]; then
        return 1
    fi
    [[ $family == 6 ]] && record_type=28
    response=$(curl "${CurlARG[@]}" "-$family" -fsS --max-time 5 \
        "https://dns.google/resolve?name=$hostname&type=$record_type") || return 1
    while IFS= read -r address; do
        if "is_valid_ipv$family" "$address"; then
            printf '%s\n' "$address"
            return
        fi
    done < <(jq -r --argjson type "$record_type" \
        'select(.Status == 0) | .Answer[]? | select(.type == $type) | .data' <<< "$response" 2>/dev/null)
    return 1
}

set_netflix_access_type() {
    local family=$1 title=$2 region=$3 peer=$4
    local address resolve result reference_status reference_region reference_peer
    netflix[utype]="${smedia[unknown]}"

    address=$(media_public_address "$family" www.netflix.com) || return 0
    resolve=$address
    [[ $family == 6 ]] && resolve="[$address]"
    resolve="www.netflix.com:443:$resolve"

    result=$(netflix_title_probe "$family" "$title" --resolve "$resolve") || return 0
    read -r reference_status reference_region reference_peer <<< "$result"
    [[ $reference_peer == "$address" ]] || return 0
    if [[ $reference_status == available && $region != - && $reference_region == "$region" ]]; then
        netflix[utype]="${smedia[native]}"
    elif [[ $peer != - && $reference_peer != "$peer" ]]; then
        if [[ $reference_status == available && $region != - && $reference_region != - ]]; then
            netflix[utype]="${smedia[dns]}"
        elif [[ $reference_status == unavailable ]]; then
            # A working Netflix Original establishes that the reference route can serve a catalog.
            result=$(netflix_title_probe "$family" 80057281 --resolve "$resolve") || return 0
            read -r reference_status reference_region reference_peer <<< "$result"
            if [[ $reference_status == available && $reference_peer == "$address" ]]; then
                netflix[utype]="${smedia[dns]}"
            fi
        fi
    fi
}

MediaUnlockTest_Netflix() {
    local family=$1 title result status region peer unavailable=0 blocked=0
    netflix=([ustatus]="${smedia[bad]}" [uregion]="${smedia[nodata]}" [utype]="${smedia[nodata]}")
    for title in 81280792 70143836; do
        result=$(netflix_title_probe "$family" "$title") || continue
        read -r status region peer <<< "$result"
        case $status in
            available)
                netflix[ustatus]="${smedia[yes]}"
                [[ $region != - ]] && netflix[uregion]="  [$region]   "
                set_netflix_access_type "$family" "$title" "$region" "$peer"
                return
                ;;
            unavailable) ((unavailable+=1)) ;;
            blocked) ((blocked+=1)) ;;
        esac
    done

    if (( unavailable == 2 )); then
        result=$(netflix_title_probe "$family" 80057281) || return 0
        read -r status region peer <<< "$result"
        if [[ $status == available ]]; then
            netflix[ustatus]="${smedia[org]}"
            [[ $region != - ]] && netflix[uregion]="  [$region]   "
            netflix[utype]="${smedia[unknown]}"
        fi
    elif (( blocked == 2 )); then
        netflix[ustatus]="${smedia[no]}"
    fi
}
function MediaUnlockTest_YouTube_Premium(){
youtube=()
local checkunlockurl="www.youtube.com"
local result1=$(Check_DNS_1 $checkunlockurl)
local result3=$(Check_DNS_3 $checkunlockurl)
local resultunlocktype=$(Get_Unlock_Type $result1 $result3)
local tmpresult=$(curl "${CurlARG[@]}" -$1 --max-time 10 -sSL -H "Accept-Language: en" -b "YSC=BiCUU3-5Gdk; CONSENT=YES+cb.20220301-11-p0.en+FX+700; GPS=1; VISITOR_INFO1_LIVE=4VwPMkB7W5A; PREF=tz=Asia.Shanghai; _gcl_au=1.1.1809531354.1646633279" "https://www.youtube.com/premium" 2>&1)
if [[ $tmpresult == "curl"* ]];then
youtube[ustatus]="${smedia[bad]}"
youtube[uregion]="${smedia[nodata]}"
youtube[utype]="${smedia[nodata]}"
return
fi
local isCN=$(echo $tmpresult|grep 'www.google.cn')
if [ -n "$isCN" ];then
youtube[ustatus]="${smedia[cn]}"
youtube[uregion]="  $Font_Red[CN]$Font_Green   "
youtube[utype]="${smedia[nodata]}"
return
fi
local isNotAvailable=$(echo $tmpresult|grep 'Premium is not available in your country')
local region=$(echo $tmpresult|sed -n 's/.*"contentRegion":"\([^"]*\)".*/\1/p')
local isAvailable=$(echo $tmpresult|grep 'ad-free')
if [ -n "$isNotAvailable" ];then
youtube[ustatus]="${smedia[noprem]}"
youtube[uregion]="${smedia[nodata]}"
youtube[utype]="${smedia[nodata]}"
return
elif [ -n "$isAvailable" ]&&[ -n "$region" ];then
youtube[ustatus]="${smedia[yes]}"
youtube[uregion]="  [$region]   "
youtube[utype]="$resultunlocktype"
return
elif [ -z "$region" ]&&[ -n "$isAvailable" ];then
youtube[ustatus]="${smedia[yes]}"
youtube[uregion]="${smedia[nodata]}"
youtube[utype]="$resultunlocktype"
return
else
youtube[ustatus]="${smedia[bad]}"
youtube[uregion]="${smedia[nodata]}"
youtube[utype]="${smedia[nodata]}"
fi
}
function MediaUnlockTest_PrimeVideo_Region(){
amazon=()
local checkunlockurl="www.primevideo.com"
local result1=$(Check_DNS_1 $checkunlockurl)
local result3=$(Check_DNS_3 $checkunlockurl)
local resultunlocktype=$(Get_Unlock_Type $result1 $result3)
local tmpresult=$(curl "${CurlARG[@]}" -$1 --user-agent "$UA_Browser" -sL --max-time 10 "https://www.primevideo.com" 2>&1)
if [[ $tmpresult == "curl"* ]];then
amazon[ustatus]="${smedia[bad]}"
amazon[uregion]="${smedia[nodata]}"
amazon[utype]="${smedia[nodata]}"
return
fi
local result=$(echo $tmpresult|grep -o -E '"currentTerritory":\s*"[A-Z]{2}"'|head -n 1|cut -d'"' -f4)
if [ -n "$result" ];then
amazon[ustatus]="${smedia[yes]}"
amazon[uregion]="  [$result]   "
amazon[utype]="$resultunlocktype"
return
else
amazon[ustatus]="${smedia[no]}"
amazon[uregion]="${smedia[nodata]}"
amazon[utype]="${smedia[nodata]}"
return
fi
}
claude_preflight() {
    local family=$1 endpoint=$2
    shift 2
    local response body code url peer status
    response=$(fetch_media_page "$family" "$endpoint" -H 'Accept: application/json' "$@") || return 1
    IFS=$'\t' read -r code url peer <<< "${response##*$'\n'}"
    [[ $url == "$endpoint" ]] || return 1
    body=${response%$'\n'*}

    case $code in
        200)
            jq -e '.message == "hello"' <<< "$body" >/dev/null 2>&1 || return 1
            status=yes
            ;;
        403)
            if [[ $body == *'/cdn-cgi/challenge-platform/'* ]]; then
                status=unknown
            else
                status=no
            fi
            ;;
        451) status=no ;;
        429) status=limited ;;
        *) return 1 ;;
    esac
    printf '%s %s\n' "$status" "${peer:--}"
}

claude_route_probe() {
    local family=$1
    shift
    local result status api_peer login_peer=- region=- egress=- trace
    result=$(claude_preflight "$family" 'https://api.anthropic.com/api/hello' "$@") || return 1
    read -r status api_peer <<< "$result"
    if [[ $status == yes ]]; then
        result=$(claude_preflight "$family" 'https://platform.claude.com/v1/oauth/hello' "$@") || return 1
        read -r status login_peer <<< "$result"
    fi

    if [[ $status == yes ]] && trace=$(curl "${CurlARG[@]}" "-$family" -fs --max-time 5 \
        "$@" 'https://api.anthropic.com/cdn-cgi/trace'); then
        read -r region egress <<< "$(awk -F= '
            { sub(/\r$/, "", $2) }
            $1 == "loc" && $2 ~ /^[A-Z][A-Z]$/ && $2 != "XX" { region = $2 }
            $1 == "ip" && $2 ~ /^[A-Fa-f0-9:.]+$/ { egress = $2 }
            END { print (region ? region : "-"), (egress ? egress : "-") }
        ' <<< "$trace")"
    fi
    printf '%s %s %s %s %s\n' "$status" "$region" "$egress" "$api_peer" "$login_peer"
}

MediaUnlockTest_Claude() {
    local family=$1 result status region egress api_peer login_peer
    local api_address login_address api_resolve login_resolve
    local control_status control_region control_egress control_api_peer control_login_peer
    claude=([ustatus]="${smedia[bad]}" [uregion]="${smedia[nodata]}" [utype]="${smedia[nodata]}")
    result=$(claude_route_probe "$family") || return 0
    read -r status region egress api_peer login_peer <<< "$result"
    claude[ustatus]="${smedia[$status]}"
    [[ $status == yes ]] || return 0
    [[ $region != - ]] && claude[uregion]="  [$region]   "
    claude[utype]="${smedia[unknown]}"

    api_address=$(media_public_address "$family" api.anthropic.com) || return 0
    login_address=$(media_public_address "$family" platform.claude.com) || return 0
    api_resolve=$api_address
    login_resolve=$login_address
    if [[ $family == 6 ]]; then
        api_resolve="[$api_address]"
        login_resolve="[$login_address]"
    fi
    result=$(claude_route_probe "$family" --resolve "api.anthropic.com:443:$api_resolve" \
        --resolve "platform.claude.com:443:$login_resolve") || return 0
    read -r control_status control_region control_egress control_api_peer control_login_peer <<< "$result"

    [[ $control_api_peer == "$api_address" ]] || return 0
    if [[ $control_login_peer != "$login_address" &&
        ( $control_status == yes || $control_login_peer != - ) ]]; then
        return 0
    fi
    if [[ $control_status == yes && $region != - && $control_region == "$region" &&
        ${egress,,} == "${IP,,}" && ${control_egress,,} == "${IP,,}" ]]; then
        claude[utype]="${smedia[native]}"
    elif [[ ( $api_peer != "$control_api_peer" ||
        ( $control_login_peer != - && $login_peer != "$control_login_peer" ) ) &&
        ( $control_status == no || ( $control_status == yes && $region != - &&
            $control_region != - && $region != "$control_region" ) ) ]]; then
        claude[utype]="${smedia[dns]}"
    fi
}
function OpenAITest(){
chatgpt=()
local checkunlockurl="chat.openai.com"
local result1=$(Check_DNS_1 $checkunlockurl)
local result2=$(Check_DNS_2 $checkunlockurl)
local result3=$(Check_DNS_3 $checkunlockurl)
local checkunlockurl="ios.chat.openai.com"
local result4=$(Check_DNS_1 $checkunlockurl)
local result5=$(Check_DNS_2 $checkunlockurl)
local result6=$(Check_DNS_3 $checkunlockurl)
local checkunlockurl="api.openai.com"
local result7=$(Check_DNS_1 $checkunlockurl)
local result8=$(Check_DNS_3 $checkunlockurl)
local resultunlocktype=$(Get_Unlock_Type $result1 $result2 $result3 $result4 $result5 $result6 $result7 $result8)
local tmpresult1=$(curl "${CurlARG[@]}" -$1 -sS --max-time 10 'https://api.openai.com/compliance/cookie_requirements' -H 'authority: api.openai.com' -H 'accept: */*' -H 'accept-language: zh-CN,zh;q=0.9' -H 'authorization: Bearer null' -H 'content-type: application/json' -H 'origin: https://platform.openai.com' -H 'referer: https://platform.openai.com/' -H 'sec-ch-ua: "Microsoft Edge";v="119", "Chromium";v="119", "Not?A_Brand";v="24"' -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-dest: empty' -H 'sec-fetch-mode: cors' -H 'sec-fetch-site: same-site' -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 Edg/119.0.0.0' 2>&1)
local tmpresult2=$(curl "${CurlARG[@]}" -$1 -sS --max-time 10 'https://ios.chat.openai.com/' -H 'authority: ios.chat.openai.com' -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' -H 'accept-language: zh-CN,zh;q=0.9' -H 'sec-ch-ua: "Microsoft Edge";v="119", "Chromium";v="119", "Not?A_Brand";v="24"' -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-dest: document' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: none' -H 'sec-fetch-user: ?1' -H 'upgrade-insecure-requests: 1' -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 Edg/119.0.0.0' 2>&1)
local result1=$(echo $tmpresult1|grep unsupported_country)
local result2=$(echo $tmpresult2|grep VPN)
if [ -n "$result1" ];then
code=$(curl "${CurlARG[@]}" -$1 -o /dev/null -sS --max-time 10 \
'https://chatgpt.com/favicon.ico' \
-H 'accept: image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8' \
-H 'authority: chatgpt.com' \
-H 'accept: */*' \
-H 'accept-language: zh-CN,zh;q=0.9' \
-H 'authorization: Bearer null' \
-H 'content-type: application/json' \
-H 'origin: https://chatgpt.com' \
-H 'referer: https://chatgpt.com/' \
-H 'sec-ch-ua: "Microsoft Edge";v="119", "Chromium";v="119", "Not?A_Brand";v="24"' \
-H 'sec-ch-ua-mobile: ?0' \
-H 'sec-ch-ua-platform: "Windows"' \
-H 'sec-fetch-dest: empty' \
-H 'sec-fetch-mode: cors' \
-H 'sec-fetch-site: same-site' \
-H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 Edg/119.0.0.0' \
-w "%{http_code}" 2>&1)
[[ $code != "403" ]]&&result1=""
fi
local countryCode="$(curl "${CurlARG[@]}" --max-time 10 -sS https://chat.openai.com/cdn-cgi/trace 2>&1|grep "loc="|awk -F= '{print $2}')"
if [ -z "$result2" ]&&[ -z "$result1" ]&&[[ $tmpresult1 != "curl"* ]]&&[[ $tmpresult2 != "curl"* ]];then
chatgpt[ustatus]="${smedia[yes]}"
chatgpt[uregion]="  [$countryCode]   "
chatgpt[utype]="$resultunlocktype"
elif [ -n "$result2" ]&&[ -n "$result1" ];then
chatgpt[ustatus]="${smedia[no]}"
chatgpt[uregion]="${smedia[nodata]}"
chatgpt[utype]="${smedia[nodata]}"
elif [ -z "$result1" ]&&[ -n "$result2" ]&&[[ $tmpresult1 != "curl"* ]];then
chatgpt[ustatus]="${smedia[web]}"
chatgpt[uregion]="  [$countryCode]   "
chatgpt[utype]="$resultunlocktype"
elif [ -n "$result1" ]&&[ -z "$result2" ];then
chatgpt[ustatus]="${smedia[app]}"
chatgpt[uregion]="  [$countryCode]   "
chatgpt[utype]="$resultunlocktype"
elif [[ $tmpresult1 == "curl"* ]]&&[ -n "$result2" ];then
chatgpt[ustatus]="${smedia[no]}"
chatgpt[uregion]="${smedia[nodata]}"
chatgpt[utype]="${smedia[nodata]}"
elif [[ $1 -eq 6 ]]&&[ -z "$result2" ]&&[[ $tmpresult2 != "curl"* ]];then
chatgpt[ustatus]="${smedia[yes]}"
chatgpt[uregion]="  [$countryCode]   "
chatgpt[utype]="$resultunlocktype"
else
chatgpt[ustatus]="${smedia[bad]}"
chatgpt[uregion]="${smedia[nodata]}"
chatgpt[utype]="${smedia[nodata]}"
fi
}
get_sorted_mx_records() {
    dig +time=2 +tries=1 +short MX "$1" | sort -n | awk 'NR == 1 { print $2 }'
}
smtp_response() {
    local seconds=$1
    shift
    local -a probe=(nc -s "$IP" -w "$seconds")
    if [[ $OSTYPE == darwin* ]]; then
        probe+=(-G "$seconds")
    elif command -v timeout >/dev/null 2>&1; then
        probe=(timeout "$((seconds+1))" "${probe[@]}")
    fi
    printf 'QUIT\r\n' | "${probe[@]}" "$@" 2>&1
}
check_email_service(){
local service=$1
local domain host response
case $service in
"Gmail")domain="gmail.com";;
"Outlook")domain="outlook.com";;
"Yahoo")domain="yahoo.com";;
"Apple")domain="me.com";;
"MailRU")domain="mail.ru";;
"AOL")domain="aol.com";;
"GMX")domain="gmx.com";;
"MailCOM")domain="mail.com";;
"163")domain="163.com";;
"Sohu")domain="sohu.com";;
"Sina")domain="sina.com";;
"QQ")domain="qq.com";;
*)return
esac
host=$(get_sorted_mx_records "$domain")
if [[ -n $host ]];then
response=$(smtp_response 4 "$host" 25)
fi
if [[ ${response:-} == 220[\ -]* ]];then
smail[$service]="$Font_Black+$Font_Suffix$Back_Green$Font_White$Font_B$service$Font_Suffix"
smailstatus[$service]="true"
smail[remote]=1
else
smail[$service]="$Font_Black-$Font_Suffix$Back_Red$Font_White$Font_B$service$Font_Suffix"
smailstatus[$service]="false"
fi
}
smtp_port_in_use() {
    if command -v ss >/dev/null 2>&1; then
        ss -H -ltn 'sport = :25' | grep -q .
    elif command -v netstat >/dev/null 2>&1; then
        netstat -an | awk '$1 ~ /^tcp/ && $4 ~ /[.:]25$/ && $NF == "LISTEN" { found=1 } END { exit !found }'
    else
        return 1
    fi
}
check_mail(){
local label=$1 index=0
progress "$label · SMTP 25"
smail[local]=0
if smtp_port_in_use;then
smail[local]=2
else
local response
response=$(smtp_response 9 -p 25 smtp.mailgun.org 25)
[[ $response == 220[\ -]* ]]&&smail[local]=1
fi
smail[remote]=0
services=("Gmail" "Outlook" "Yahoo" "Apple" "QQ" "MailRU" "AOL" "GMX" "MailCOM" "163" "Sohu" "Sina")
for service in "${services[@]}";do
((++index))
run_probe "$label · $service ($index/${#services[@]})" check_email_service "$service"
done
}
# Bundle the DNSBL zones for standalone use.
dnsbl_zones=(
    0outspam.fusionzero.com 0spam-killlist.fusionzero.com 0spam.fusionzero.com
    0spamtrust.fusionzero.com 0spamurl.fusionzero.com 3y.spam.mrs.kithrup.com 88.blocklist.zap
    abuse.rfc-clueless.org abuse.rfc-ignorant.org access.redhawk.org accredit.habeas.com
    admin.bl.kundenserver.de all.ascc.dnsbl.bit.nl all.dnsbl.bit.nl all.s5h.net all.spam-rbl.fr
    all.spamrats.com all.v6.ascc.dnsbl.bit.nl aspews.dnsbl.sorbs.net aspews.ext.sorbs.net
    assholes.madscience.nl auth.spamrats.com autowork.drbl.ks.cz b.barracudacentral.org
    backscatter.spameatingmonkey.net badconf.rhsbl.sorbs.net badnets.spameatingmonkey.net
    ban.zebl.zoneedit.com bandwidth-pigs.monkeys.com bb.barracudacentral.org bitonly.dnsbl.bit.nl
    bl.blocklist.de bl.blueshore.net bl.borderworlds.dk bl.deadbeef.com bl.drmx.org bl.fmb.la
    bl.ipv6.spameatingmonkey.net bl.konstant.no bl.mailspike.net bl.mailspike.org bl.mav.com.br
    bl.mipspace.com bl.nszones.com bl.reynolds.net.au bl.scientificspam.net bl.score.senderscore.com
    bl.shlink.orgdul.ru bl.spamcannibal.org bl.spamcop.net bl.spameatingmonkey.net bl.spamstinks.com
    bl.spamthwart.com bl.student.pw.edu.pl bl.suomispam.net bl.tolkien.dk black.junkemailfilter.com
    blackhole.compu.net blackholes.brainerd.net blackholes.easynet.nl blackholes.five-ten-sg.com
    blackholes.sandes.dk blacklist.fpsn.net blacklist.hostkarma.com blacklist.informationwave.net
    blacklist.mail.ops.asp.att.net blacklist.mailrelay.att.net blacklist.sci.kun.nl
    blacklist.sci.ru.nl blacklist.sequoia.ops.asp.att.net block.ascams.com block.blars.org
    block.dnsbl.sorbs.net blocked.asgardnet.org blocked.hilli.dk blocklist.squawk.com
    blocklist2.squawk.com bogon.lbl.lagengymnastik.dk bogons.cymru.com bogusmx.rfc-clueless.org
    bogusmx.rfc-ignorant.org bsb.empty.us bsb.spamlookup.net cart00ney.surriel.com catchspam.com
    china.rominet.net client-domain.sjesl.monkeys.com combined.abuse.ch combined.rbl.msrbl.net
    communicado.fmb.la csi.cloudmark.com czdynamic.drbl.ks.cz db.rurbl.ru db.wpbl.info
    dbl.suomispam.net dev.null.dk dialup.blacklist.jippg.org dialup.drbl.sandy.ru
    dialups.mail-abuse.org dnsbl-0.uceprotect.net dnsbl-1.uceprotect.net dnsbl-2.uceprotect.net
    dnsbl-3.uceprotect.net dnsbl.abuse.ch dnsbl.anticaptcha.net dnsbl.antispam.or.id
    dnsbl.calivent.com.pe dnsbl.clue-by-4.org dnsbl.cobion.com dnsbl.cyberlogic.net dnsbl.delink.net
    dnsbl.dronebl.org dnsbl.forefront.microsoft.com dnsbl.httpbl.org dnsbl.inps.de dnsbl.ioerror.us
    dnsbl.justspam.org dnsbl.kempt.net dnsbl.madavi.de dnsbl.mags.net dnsbl.mailshell.net
    dnsbl.mcu.edu.tw dnsbl.net.ua dnsbl.pagedirect.net dnsbl.rangers.eu.org dnsbl.rizon.net
    dnsbl.rv-soft.info dnsbl.rymsho.ru dnsbl.sorbs.net dnsbl.technoirc.org dnsbl.tornevall.org
    dnsbl.webequipped.com dnsbl.wpbl.pc9.org dnsbl.zapbl.net dnsbl6.anticaptcha.net dnsblchile.org
    dnsrbl.swinog.ch dnswl.inps.de dnswl.leisi.net dob.sibl.support-intelligence.net drone.abuse.ch
    dronebl.noderebellion.net dsn.rfc-clueless.org dsn.rfc-ignorant.org duinv.aupads.org
    dul.dnsbl.sorbs.net dul.dnsbl.sorbs.netdul.ru dul.orca.bc.ca dul.pacifier.net dul.ru
    dyna.spamrats.com dynablock.easynet.nl dynamic.dnsbl.rangers.eu.org dyndns.rbl.jp
    dynip.rothen.com elitist.rfc-clueless.org endn.bl.reynolds.net.au escalations.dnsbl.sorbs.net
    eswlrev.dnsbl.rediris.es ex.dnsbl.org exitnodes.tor.dnsbl.sectoor.de
    exitnodes.tor.dnsbl.sectoor.dehttp.dnsbl.sorbs.net feb.spamlab.com fnrbl.fast.net
    formmail.relays.monkeys.com fresh.dict.rbl.arix.com fresh.sa_slip.rbl.arix.com
    fresh.spameatingmonkey.net fresh10.spameatingmonkey.net fresh15.spameatingmonkey.net
    fulldom.rfc-clueless.org geobl.spameatingmonkey.net gl.suomispam.net
    helo-domain.sjesl.monkeys.com hil.habeas.com hong-kong.rominet.net hostkarma.junkemailfilter.com
    http.dnsbl.sorbs.net httpbl.abuse.ch hul.habeas.com iadb.isipp.com iadb2.isipp.com
    iddb.isipp.com images.rbl.msrbl.net in.dnsbl.org intercept.datapacket.net intruders.docs.uu.se
    ipbl.zeustracker.abuse.ch ips.backscatterer.org ipv6.all.dnsbl.bit.nl ipv6.all.s5h.net
    ipwhois.rfc-ignorant.org is-tor.kewlio.net.uk ispmx.pofon.foobar.hu ix.dnsbl.manitu.net
    korea.rominet.net korea.services.net l1.apews.org l1.apews.rhsbl.sorbs.net l1.bbfh.ext.sorbs.net
    l1.spews.dnsbl.sorbs.net l2.apews.dnsbl.sorbs.net l2.bbfh.ext.sorbs.net l2.spews.dnsbl.sorbs.net
    l3.bbfh.ext.sorbs.net l4.bbfh.ext.sorbs.net lame.dnsbl.rangers.eu.org lbl.lagengymnastik.dk
    list.anonwhois.net list.bbfh.org list.blogspambl.com list.dnswl.org
    mail-abuse.blacklist.jippg.org mail.people.it manual.orbz.gst-group.co.uk misc.dnsbl.sorbs.net
    msgid.bl.gweep.ca mtawlrev.dnsbl.rediris.es multi.surbl.org netbl.spameatingmonkey.net
    netblock.pedantic.org netblockbl.spamgrouper.com netscan.rbl.blockedservers.com
    new.dnsbl.sorbs.net new.spam.dnsbl.sorbs.net nml.mail-abuse.org no-more-funn.moensted.dk
    nobl.junkemailfilter.com nomail.rhsbl.sorbs.net noptr.spamrats.com noservers.dnsbl.sorbs.net
    nospam.ant.pl nsbl.fmb.la old.dnsbl.sorbs.net old.spam.dnsbl.sorbs.net opm.tornevall.org
    orbs.dorkslayers.com orbz.gst-group.co.uk origin6.asn.cymru.com orvedb.aupads.org
    pacbelldsl.compu.net pdl.bl.reynolds.net.au phishing.rbl.msrbl.net plus.bondedsender.org
    pm0-no-more.compu.net pofon.foobar.hu policy.lbl.lagengymnastik.dk postmaster.rfc-clueless.org
    postmaster.rfc-ignorant.org ppbl.beat.st probes.dnsbl.net.auproxy.bl.gweep.ca
    problems.dnsbl.sorbs.net proxies.blackholes.easynet.nl proxies.dnsbl.sorbs.net
    proxies.exsilia.net proxy.bl.gweep.ca proxy.block.transip.nl proxy.drbl.be.net.ru
    psbl.surriel.com pss.spambusters.org.ar q.mail-abuse.com query.bondedsender.org
    query.senderbase.org r.mail-abuse.com rabl.nuclearelephant.com random.bl.gweep.ca rbl.abuse.ro
    rbl.blakjak.net rbl.blockedservers.com rbl.bulkfeeds.jp rbl.dns-servicios.com rbl.echelon.pl
    rbl.efnet.org rbl.efnethelp.net rbl.efnetrbl.org rbl.eznettools.com rbl.fasthosts.co.uk
    rbl.firstbase.com rbl.init1.nl rbl.interserver.net rbl.ipv6wl.eu rbl.jp rbl.lugh.ch
    rbl.ma.krakow.pl rbl.mail-abuse.org rbl.pil.dk rbl.polarcomm.net rbl.rope.net rbl.schulte.org
    rbl.snark.net rbl.spamlab.com rbl.suresupport.com rbl.talkactive.net rbl.triumf.ca
    rbl2.triumf.ca rdts.bl.reynolds.net.au recent.dnsbl.sorbs.net recent.spam.dnsbl.sorbs.net
    relayips.rbl.shub-inter.net relays.bl.gweep.ca relays.bl.kundenserver.de relays.dnsbl.sorbs.net
    relays.dorkslayers.com relays.nether.net relays.radparker.com relays.sandes.dk rep.mailspike.net
    reputation-domain.rbl.scrolloutf1.com reputation-ip.rbl.scrolloutf1.com
    reputation-ns.rbl.scrolloutf1.com residential.block.transip.nl rf.senderbase.org rhsbl.rymsho.ru
    rhsbl.scientificspam.net rhsbl.sorbs.net rhsbl.zapbl.net rsbl.aupads.org sa-accredit.habeas.com
    sa.senderbase.org safe.dnsbl.sorbs.net sbl.nszones.com schizo-bl.kundenserver.de
    score.senderscore.com sender-address.sjesl.monkeys.com sender-domain-validate.sjesl.monkeys.com
    sender-domain.sjesl.monkeys.com short.fmb.la short.rbl.jp singular.ttk.pte.hu
    smtp.dnsbl.sorbs.net socks.dnsbl.sorbs.net sohul.habeas.com spam.abuse.ch
    spam.dnsbl.anonmails.de spam.dnsbl.rangers.eu.org spam.dnsbl.sorbs.net spam.exsilia.net
    spam.lbl.lagengymnastik.dk spam.olsentech.net spam.pedantic.org spam.rbl.blockedservers.com
    spam.rbl.msrbl.net spam.shri.net spam.spamrats.com spam.wonk.org spamblock.kundenserver.de
    spambot.bls.digibase.ca spamdomain.block.transip.nl spamdomains.blackholes.easynet.nl
    spamguard.leadmon.net spamips.rbl.shub-inter.net spamlist.or.kr spamrbl.imp.ch
    spamsource.block.transip.nl spamsources.fabel.dk spamsupport.dnsbl.rangers.eu.org
    spews.block.transip.nl st.technovision.dk stale.dict.rbl.arix.com stale.sa_slip.arix.com
    superblock.ascams.com taiwan.rominet.net tor.dan.me.uk tor.dnsbl.sectoor.de tor.efnet.org
    torexit.dan.me.uk torserver.tor.dnsbl.sectoor.de truncate.gbudb.net trusted.nether.net
    ubl.lashback.com ubl.nszones.com ubl.unsubscore.com unsure.nether.net uribl.abuse.ro
    uribl.pofon.foobar.hu uribl.spameatingmonkey.net uribl.swinog.ch uribl.zeustracker.abuse.ch
    urired.spameatingmonkey.net url.rbl.jp v4.fullbogons.cymru.com v6.fullbogons.cymru.com
    virbl.bit.nl virbl.dnsbl.bit.nl virus.rbl.jp virus.rbl.msrbl.net vote.drbl.be.net.ru
    vote.drbl.caravan.ru vote.drbl.croco.net vote.drbl.dataforce.net vote.drbl.gremlin.ru
    vote.drbl.host.kz vote.drbldf.dsbl.ru vouch.dwl.spamhaus.org wadb.isipp.com wbl.triumf.ca
    wdl.bl.reynolds.net.au web.dnsbl.sorbs.net web.rbl.msrbl.net whois.rfc-clueless.org
    whois.rfc-ignorant.org wl.mailspike.net wl.nszones.com wl.summersault.com
    wl.trusted-forwarder.org work.drbl.caravan.ru work.drbl.croco.net work.drbl.dataforce.net
    work.drbl.gremlin.ru work.drbl.host.kz work.drbldf.dsbl.ru worm.dnsbl.rangers.eu.org
    wormrbl.imp.ch worms-bl.kundenserver.de wpb.bl.reynolds.net.au ybl.megacity.org z.mailspike.net
    zebl.zoneedit.com zombie.dnsbl.sorbs.net zta.birdsong.org ztl.dorkslayers.com
)
check_dnsbl_parallel(){
local ip_to_check=$1
local parallel_jobs=$2
local label=$3
local -a zones
mapfile -t zones < <(printf '%s\n' "${dnsbl_zones[@]}" | sort -u)
local zone_count=${#zones[@]}
progress "$label · 0/$zone_count"
smail[t]=0
smail[c]=0
smail[m]=0
smail[b]=0
local reversed_ip
reversed_ip=$(awk -F. '{print $4"."$3"."$2"."$1}' <<< "$ip_to_check")
local total=0
local clean=0
local blacklisted=0
local other=0
printf '%s\n' "${zones[@]}" |
    xargs -P "$parallel_jobs" -I {} "$BASH" -c '
        case $(dig +time=2 +tries=1 +short "$1.$2" A) in
            ""|127.255.255.*) echo Clean ;;
            127.0.0.2) echo Blacklisted ;;
            *) echo Other ;;
        esac
    ' _ "$reversed_ip" {} | {
while IFS= read -r line;do
((total++))
case "$line" in
"Clean")((clean++));;
"Blacklisted")((blacklisted++));;
*)((other++))
esac
if (( total % 25 == 0 || total == zone_count )); then
    progress "$label · $total/$zone_count"
fi
done
smail[t]="$total"
smail[c]="$clean"
smail[m]="$other"
smail[b]="$blacklisted"
echo "${smail[t]} ${smail[c]} ${smail[m]} ${smail[b]}"
}
}
check_dnsbl(){
local num_array=($(check_dnsbl_parallel "$1" "$2" "$3"))
smail[t]=${num_array[0]:-0}
smail[c]=${num_array[1]:-0}
smail[m]=${num_array[2]:-0}
smail[b]=${num_array[3]:-0}
smail[sdnsbl]="$Font_Cyan${smail[dnsbl]}  ${smail[available]}${smail[t]}   ${smail[clean]}${smail[c]}   ${smail[marked]}${smail[m]}   ${smail[blacklisted]}${smail[b]}$Font_Suffix"
}
show_head(){
echo -ne "$(printf '%72s'|tr ' ' '#')\n"
if [[ $mode_lite -eq 0 ]];then
if [ $fullIP -eq 1 ];then
calc_padding "$(printf '%*s' "${shead[ltitle]}" '')$IP" 72
echo -ne "$PADDING$Font_B${shead[title]}$Font_Cyan$IP$Font_Suffix\n"
else
calc_padding "$(printf '%*s' "${shead[ltitle]}" '')$IPhide" 72
echo -ne "$PADDING$Font_B${shead[title]}$Font_Cyan$IPhide$Font_Suffix\n"
fi
else
if [ $fullIP -eq 1 ];then
calc_padding "$(printf '%*s' "${shead[ltitle_lite]}" '')$IP" 72
echo -ne "$PADDING$Font_B${shead[title_lite]}$Font_Cyan$IP$Font_Suffix\n"
else
calc_padding "$(printf '%*s' "${shead[ltitle_lite]}" '')$IPhide" 72
echo -ne "$PADDING$Font_B${shead[title_lite]}$Font_Cyan$IPhide$Font_Suffix\n"
fi
fi
calc_padding "$(printf '%*s' "${shead[ltime]}" '')${shead[time_raw]}" 72
printf '%s%s\n' "$PADDING" "${shead[time]}"
echo -ne "$(printf '%72s'|tr ' ' '#')\n"
}
show_basic(){
if [[ $uses_ipinfo_location -eq 1 ]];then
echo -ne "${sbasic[title_with_location_fallback]}\n"
else
echo -ne "${sbasic[title]}\n"
fi
if [[ -n ${maxmind[asn]} && ${maxmind[asn]} != "null" ]];then
echo -ne "$Font_Cyan${sbasic[asn]}${Font_Green}AS${maxmind[asn]}$Font_Suffix\n"
echo -ne "$Font_Cyan${sbasic[org]}$Font_Green${maxmind[org]}$Font_Suffix\n"
else
echo -ne "$Font_Cyan${sbasic[asn]}${sbasic[noasn]}$Font_Suffix\n"
fi
if [[ ${maxmind[dms]} != "null" && ${maxmind[map]} != "null" ]];then
echo -ne "$Font_Cyan${sbasic[location]}$Font_Green${maxmind[dms]}$Font_Suffix\n"
echo -ne "$Font_Cyan${sbasic[map]}$Font_U$Font_Green${maxmind[map]}$Font_Suffix\n"
fi
local city_info=""
if [[ -n ${maxmind[sub]} && ${maxmind[sub]} != "null" ]];then
city_info+="${maxmind[sub]}"
fi
if [[ -n ${maxmind[city]} && ${maxmind[city]} != "null" ]];then
[[ -n $city_info ]]&&city_info+=", "
city_info+="${maxmind[city]}"
fi
if [[ -n ${maxmind[post]} && ${maxmind[post]} != "null" ]];then
[[ -n $city_info ]]&&city_info+=", "
city_info+="${maxmind[post]}"
fi
if [[ -n $city_info ]];then
echo -ne "$Font_Cyan${sbasic[city]}$Font_Green$city_info$Font_Suffix\n"
fi
if [[ -n ${maxmind[countrycode]} && ${maxmind[countrycode]} != "null" ]];then
echo -ne "$Font_Cyan${sbasic[country]}$Font_Green[${maxmind[countrycode]}]${maxmind[country]}$Font_Suffix"
if [[ -n ${maxmind[continentcode]} && ${maxmind[continentcode]} != "null" ]];then
echo -ne "$Font_Green, [${maxmind[continentcode]}]${maxmind[continent]}$Font_Suffix\n"
else
echo -ne "\n"
fi
elif [[ -n ${maxmind[continentcode]} && ${maxmind[continentcode]} != "null" ]];then
echo -ne "$Font_Cyan${sbasic[continent]}$Font_Green[${maxmind[continentcode]}]${maxmind[continent]}$Font_Suffix\n"
fi
if [[ -n ${maxmind[regcountrycode]} && ${maxmind[regcountrycode]} != "null" ]];then
echo -ne "$Font_Cyan${sbasic[regcountry]}$Font_Green[${maxmind[regcountrycode]}]${maxmind[regcountry]}$Font_Suffix\n"
fi
if [[ -n ${maxmind[timezone]} && ${maxmind[timezone]} != "null" ]];then
echo -ne "$Font_Cyan${sbasic[timezone]}$Font_Green${maxmind[timezone]}$Font_Suffix\n"
fi
if [[ -n ${maxmind[countrycode]} && ${maxmind[countrycode]} != "null" ]];then
if [ "${maxmind[countrycode]}" == "${maxmind[regcountrycode]}" ];then
echo -ne "$Font_Cyan${sbasic[type]}$Back_Green$Font_B$Font_White${sbasic[type0]}$Font_Suffix\n"
else
echo -ne "$Font_Cyan${sbasic[type]}$Back_Red$Font_B$Font_White${sbasic[type1]}$Font_Suffix\n"
fi
fi
}
show_basic_lite(){
echo -ne "${sbasic[title_lite]}\n"
if [[ -n ${ipinfo[asn]} && ${ipinfo[asn]} != "null" ]];then
echo -ne "$Font_Cyan${sbasic[asn]}${Font_Green}AS${ipinfo[asn]}$Font_Suffix\n"
echo -ne "$Font_Cyan${sbasic[org]}$Font_Green${ipinfo[org]}$Font_Suffix\n"
else
echo -ne "$Font_Cyan${sbasic[asn]}${sbasic[noasn]}$Font_Suffix\n"
fi
if [[ ${ipinfo[dms]} != "null" && ${ipinfo[map]} != "null" ]];then
echo -ne "$Font_Cyan${sbasic[location]}$Font_Green${ipinfo[dms]}$Font_Suffix\n"
echo -ne "$Font_Cyan${sbasic[map]}$Font_U$Font_Green${ipinfo[map]}$Font_Suffix\n"
fi
local city_info=""
if [[ -n ${ipinfo[sub]} && ${ipinfo[sub]} != "null" ]];then
city_info+="${ipinfo[sub]}"
fi
if [[ -n ${ipinfo[city]} && ${ipinfo[city]} != "null" ]];then
[[ -n $city_info ]]&&city_info+=", "
city_info+="${ipinfo[city]}"
fi
if [[ -n ${ipinfo[post]} && ${ipinfo[post]} != "null" ]];then
[[ -n $city_info ]]&&city_info+=", "
city_info+="${ipinfo[post]}"
fi
if [[ -n $city_info ]];then
echo -ne "$Font_Cyan${sbasic[city]}$Font_Green$city_info$Font_Suffix\n"
fi
if [[ -n ${ipinfo[countrycode]} && ${ipinfo[countrycode]} != "null" ]];then
echo -ne "$Font_Cyan${sbasic[country]}$Font_Green[${ipinfo[countrycode]}]${ipinfo[country]}$Font_Suffix"
if [[ -n ${ipinfo[continent]} && ${ipinfo[continent]} != "null" ]];then
echo -ne "$Font_Green, ${ipinfo[continent]}$Font_Suffix\n"
else
echo -ne "\n"
fi
elif [[ -n ${ipinfo[continent]} && ${ipinfo[continent]} != "null" ]];then
echo -ne "$Font_Cyan${sbasic[continent]}$Font_Green${ipinfo[continent]}$Font_Suffix\n"
fi
if [[ -n ${ipinfo[regcountrycode]} && ${ipinfo[regcountrycode]} != "null" ]];then
echo -ne "$Font_Cyan${sbasic[regcountry]}$Font_Green[${ipinfo[regcountrycode]}]${ipinfo[regcountry]}$Font_Suffix\n"
fi
if [[ -n ${ipinfo[timezone]} && ${ipinfo[timezone]} != "null" ]];then
echo -ne "$Font_Cyan${sbasic[timezone]}$Font_Green${ipinfo[timezone]}$Font_Suffix\n"
fi
if [[ -n ${ipinfo[countrycode]} && ${ipinfo[countrycode]} != "null" ]];then
if [ "${ipinfo[countrycode]}" == "${ipinfo[regcountrycode]}" ];then
echo -ne "$Font_Cyan${sbasic[type]}$Back_Green$Font_B$Font_White${sbasic[type0]}$Font_Suffix\n"
else
echo -ne "$Font_Cyan${sbasic[type]}$Back_Red$Font_B$Font_White${sbasic[type1]}$Font_Suffix\n"
fi
fi
}
show_type(){
echo -ne "${stype[title]}\n"
echo -ne "$Font_Cyan${stype[db]}$Font_I   IPinfo    ipregistry    ipapi    IP2Location   AbuseIPDB $Font_Suffix\n"
echo -ne "$Font_Cyan${stype[usetype]}$Font_Suffix${ipinfo[susetype]}${ipregistry[susetype]}${ipapi[susetype]}${ip2location[susetype]}${abuseipdb[susetype]}\n"
echo -ne "$Font_Cyan${stype[comtype]}$Font_Suffix${ipinfo[scomtype]}${ipregistry[scomtype]}${ipapi[scomtype]}${ip2location[scomtype]}\n"
}
show_type_lite(){
echo -ne "${stype[title]}\n"
echo -ne "$Font_Cyan${stype[db]}$Font_I   IPinfo    ipregistry    ipapi $Font_Suffix\n"
echo -ne "$Font_Cyan${stype[usetype]}$Font_Suffix${ipinfo[susetype]}${ipregistry[susetype]}${ipapi[susetype]}\n"
echo -ne "$Font_Cyan${stype[comtype]}$Font_Suffix${ipinfo[scomtype]}${ipregistry[scomtype]}${ipapi[scomtype]}\n"
}
sscore_text(){
local text="$1"
local p2=$2
local p3=$3
local p4=$4
local p5=$5
local p6=$6
local tmplen
local tmp
if ((p2>=p4));then
tmplen=$((49+15*(p2-p4)/(p5-p4)-p6))
elif ((p2>=p3));then
tmplen=$((33+16*(p2-p3)/(p4-p3)-p6))
elif ((p2>=0));then
tmplen=$((17+16*p2/p3-p6))
else
tmplen=0
fi
tmp=$(printf '%*s' $tmplen '')
local total_length=${#tmp}
local text_length=${#text}
local tmp1="${tmp:1:total_length-text_length}$text|"
sscore[text1]="${tmp1:1:16-p6}"
sscore[text2]="${tmp1:17-p6:16}"
sscore[text3]="${tmp1:33-p6:16}"
sscore[text4]="${tmp1:49-p6}"
}
show_score(){
echo -ne "${sscore[title]}\n"
echo -ne "${sscore[range]}\n"
if [[ -n ${ip2location[score]} && $mode_lite -eq 0 ]];then
sscore_text "${ip2location[score]}" ${ip2location[score]} 33 66 99 13
echo -ne "${Font_Cyan}IP2Location${sscore[colon]}$Font_White$Font_B${sscore[text1]}$Back_Green${sscore[text2]}$Back_Yellow${sscore[text3]}$Back_Red${sscore[text4]}$Font_Suffix${ip2location[risk]}\n"
fi
if [[ -n ${scamalytics[score]} ]];then
sscore_text "${scamalytics[score]}" ${scamalytics[score]} 20 60 100 13
echo -ne "${Font_Cyan}Scamalytics${sscore[colon]}$Font_White$Font_B${sscore[text1]}$Back_Green${sscore[text2]}$Back_Yellow${sscore[text3]}$Back_Red${sscore[text4]}$Font_Suffix${scamalytics[risk]}\n"
fi
if [[ -n ${ipapi[score]} ]];then
local tmp_score=$(echo "${ipapi[scorenum]} * 10000 / 1"|bc)
sscore_text "${ipapi[score]}" $tmp_score 85 300 10000 7
echo -ne "${Font_Cyan}ipapi${sscore[colon]}$Font_White$Font_B${sscore[text1]}$Back_Green${sscore[text2]}$Back_Yellow${sscore[text3]}$Back_Red${sscore[text4]}$Font_Suffix${ipapi[risk]}\n"
fi
if [[ $mode_lite -eq 0 ]];then
sscore_text "${abuseipdb[score]}" ${abuseipdb[score]} 25 25 100 11
[[ -n ${abuseipdb[score]} ]]&&echo -ne "${Font_Cyan}AbuseIPDB${sscore[colon]}$Font_White$Font_B${sscore[text1]}$Back_Green${sscore[text2]}$Back_Yellow${sscore[text3]}$Back_Red${sscore[text4]}$Font_Suffix${abuseipdb[risk]}\n"
if [ -n "${ipqs[score]}" ]&&[ "${ipqs[score]}" != "null" ];then
sscore_text "${ipqs[score]}" ${ipqs[score]} 75 85 100 6
echo -ne "${Font_Cyan}IPQS${sscore[colon]}$Font_White$Font_B${sscore[text1]}$Back_Green${sscore[text2]}$Back_Yellow${sscore[text3]}$Back_Red${sscore[text4]}$Font_Suffix${ipqs[risk]}\n"
fi
fi
sscore_text " " ${dbip[score]} 33 66 100 7
[[ -n ${dbip[risk]} ]]&&echo -ne "${Font_Cyan}DB-IP${sscore[colon]}$Font_White$Font_B${sscore[text1]}$Back_Green${sscore[text2]}$Back_Yellow${sscore[text3]}$Back_Red${sscore[text4]}$Font_Suffix${dbip[risk]}\n"
}
format_factor(){
local tmp_txt="  "
if [[ $1 == "true" ]];then
tmp_txt+="${sfactor[yes]}"
elif [[ $1 == "false" ]];then
tmp_txt+="${sfactor[no]}"
elif [ ${#1} -eq 2 ];then
tmp_txt+="$Font_Green[$1]$Font_Suffix"
else
tmp_txt+="${sfactor[na]}"
fi
tmp_txt+="    "
if [[ $2 == "true" ]];then
tmp_txt+="${sfactor[yes]}"
elif [[ $2 == "false" ]];then
tmp_txt+="${sfactor[no]}"
elif [ ${#2} -eq 2 ];then
tmp_txt+="$Font_Green[$2]$Font_Suffix"
else
tmp_txt+="${sfactor[na]}"
fi
tmp_txt+="    "
if [[ $3 == "true" ]];then
tmp_txt+="${sfactor[yes]}"
elif [[ $3 == "false" ]];then
tmp_txt+="${sfactor[no]}"
elif [ ${#3} -eq 2 ];then
tmp_txt+="$Font_Green[$3]$Font_Suffix"
else
tmp_txt+="${sfactor[na]}"
fi
tmp_txt+="    "
if [[ $4 == "true" ]];then
tmp_txt+="${sfactor[yes]}"
elif [[ $4 == "false" ]];then
tmp_txt+="${sfactor[no]}"
elif [ ${#4} -eq 2 ];then
tmp_txt+="$Font_Green[$4]$Font_Suffix"
else
tmp_txt+="${sfactor[na]}"
fi
if [[ $mode_lite -eq 0 ]];then
tmp_txt+="    "
if [[ $5 == "true" ]];then
tmp_txt+="${sfactor[yes]}"
elif [[ $5 == "false" ]];then
tmp_txt+="${sfactor[no]}"
elif [ ${#5} -eq 2 ];then
tmp_txt+="$Font_Green[$5]$Font_Suffix"
else
tmp_txt+="${sfactor[na]}"
fi
tmp_txt+="    "
if [[ $6 == "true" ]];then
tmp_txt+="${sfactor[yes]}"
elif [[ $6 == "false" ]];then
tmp_txt+="${sfactor[no]}"
elif [ ${#6} -eq 2 ];then
tmp_txt+="$Font_Green[$6]$Font_Suffix"
else
tmp_txt+="${sfactor[na]}"
fi
tmp_txt+="    "
if [[ $7 == "true" ]];then
tmp_txt+="${sfactor[yes]}"
elif [[ $7 == "false" ]];then
tmp_txt+="${sfactor[no]}"
elif [ ${#7} -eq 2 ];then
tmp_txt+="$Font_Green[$7]$Font_Suffix"
else
tmp_txt+="${sfactor[na]}"
fi
tmp_txt+="    "
if [[ $8 == "true" ]];then
tmp_txt+="${sfactor[yes]}"
elif [[ $8 == "false" ]];then
tmp_txt+="${sfactor[no]}"
elif [ ${#8} -eq 2 ];then
tmp_txt+="$Font_Green[$8]$Font_Suffix"
else
tmp_txt+="${sfactor[na]}"
fi
fi
echo "$tmp_txt"
}
show_factor(){
local tmp_factor=""
echo -ne "${sfactor[title]}\n"
echo -ne "$Font_Cyan${sfactor[factor]}${Font_I}IP2Location ipapi ipregistry IPQS Scamalytics ipdata IPinfo DB-IP$Font_Suffix\n"
tmp_factor=$(format_factor "${ip2location[countrycode]}" "${ipapi[countrycode]}" "${ipregistry[countrycode]}" "${ipqs[countrycode]}" "${scamalytics[countrycode]}" "${ipdata[countrycode]}" "${ipinfo[countrycode]}" "${dbip[countrycode]}")
echo -ne "$Font_Cyan${sfactor[countrycode]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[proxy]}" "${ipapi[proxy]}" "${ipregistry[proxy]}" "${ipqs[proxy]}" "${scamalytics[proxy]}" "${ipdata[proxy]}" "${ipinfo[proxy]}" "${dbip[proxy]}")
echo -ne "$Font_Cyan${sfactor[proxy]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[tor]}" "${ipapi[tor]}" "${ipregistry[tor]}" "${ipqs[tor]}" "${scamalytics[tor]}" "${ipdata[tor]}" "${ipinfo[tor]}" "${dbip[tor]}")
echo -ne "$Font_Cyan${sfactor[tor]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[vpn]}" "${ipapi[vpn]}" "${ipregistry[vpn]}" "${ipqs[vpn]}" "${scamalytics[vpn]}" "${ipdata[vpn]}" "${ipinfo[vpn]}" "${dbip[vpn]}")
echo -ne "$Font_Cyan${sfactor[vpn]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[server]}" "${ipapi[server]}" "${ipregistry[server]}" "${ipqs[server]}" "${scamalytics[server]}" "${ipdata[server]}" "${ipinfo[server]}" "${dbip[server]}")
echo -ne "$Font_Cyan${sfactor[server]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[abuser]}" "${ipapi[abuser]}" "${ipregistry[abuser]}" "${ipqs[abuser]}" "${scamalytics[abuser]}" "${ipdata[abuser]}" "${ipinfo[abuser]}" "${dbip[abuser]}")
echo -ne "$Font_Cyan${sfactor[abuser]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ip2location[robot]}" "${ipapi[robot]}" "${ipregistry[robot]}" "${ipqs[robot]}" "${scamalytics[robot]}" "${ipdata[robot]}" "${ipinfo[robot]}" "${dbip[robot]}")
echo -ne "$Font_Cyan${sfactor[robot]}$Font_Suffix$tmp_factor\n"
}
show_factor_lite(){
local tmp_factor=""
echo -ne "${sfactor[title]}\n"
echo -ne "$Font_Cyan${sfactor[factor]}$Font_I    ipapi ipregistry IPinfo DB-IP$Font_Suffix\n"
tmp_factor=$(format_factor "${ipapi[countrycode]}" "${ipregistry[countrycode]}" "${ipinfo[countrycode]}" "${dbip[countrycode]}")
echo -ne "$Font_Cyan${sfactor[countrycode]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ipapi[proxy]}" "${ipregistry[proxy]}" "${ipinfo[proxy]}" "${dbip[proxy]}")
echo -ne "$Font_Cyan${sfactor[proxy]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ipapi[tor]}" "${ipregistry[tor]}" "${ipinfo[tor]}" "${dbip[tor]}")
echo -ne "$Font_Cyan${sfactor[tor]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ipapi[vpn]}" "${ipregistry[vpn]}" "${ipinfo[vpn]}" "${dbip[vpn]}")
echo -ne "$Font_Cyan${sfactor[vpn]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ipapi[server]}" "${ipregistry[server]}" "${ipinfo[server]}" "${dbip[server]}")
echo -ne "$Font_Cyan${sfactor[server]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ipapi[abuser]}" "${ipregistry[abuser]}" "${ipinfo[abuser]}" "${dbip[abuser]}")
echo -ne "$Font_Cyan${sfactor[abuser]}$Font_Suffix$tmp_factor\n"
tmp_factor=$(format_factor "${ipapi[robot]}" "${ipregistry[robot]}" "${ipinfo[robot]}" "${dbip[robot]}")
echo -ne "$Font_Cyan${sfactor[robot]}$Font_Suffix$tmp_factor\n"
}
show_media(){
echo -ne "${smedia[title]}\n"
echo -ne "$Font_Cyan${smedia[meida]}$Font_I TikTok   Disney+  Netflix Youtube  AmazonPV  Claude   ChatGPT $Font_Suffix\n"
echo -ne "$Font_Cyan${smedia[status]}${tiktok[ustatus]}${disney[ustatus]}${netflix[ustatus]}${youtube[ustatus]}${amazon[ustatus]}${claude[ustatus]}${chatgpt[ustatus]}$Font_Suffix\n"
echo -ne "$Font_Cyan${smedia[region]}$Font_Green${tiktok[uregion]}${disney[uregion]}${netflix[uregion]}${youtube[uregion]}${amazon[uregion]}${claude[uregion]}${chatgpt[uregion]}$Font_Suffix\n"
echo -ne "$Font_Cyan${smedia[type]}${tiktok[utype]}${disney[utype]}${netflix[utype]}${youtube[utype]}${amazon[utype]}${claude[utype]}${chatgpt[utype]}$Font_Suffix\n"
}
show_mail(){
echo -ne "${smail[title]}\n"
if [ ${smail[local]} -eq 1 ];then
echo -ne "$Font_Cyan${smail[port]}$Font_Suffix${smail[yes]}\n"
elif [ ${smail[local]} -eq 2 ];then
echo -ne "$Font_Cyan${smail[port]}$Font_Suffix${smail[occupied]}\n"
else
echo -ne "$Font_Cyan${smail[port]}$Font_Suffix${smail[no]}\n"
fi
if [ ${smail[remote]} -eq 1 ];then
echo -ne "$Font_Cyan${smail[provider]}$Font_Suffix"
for service in "${services[@]}";do
echo -ne "${smail[$service]}"
done
echo ""
else
echo -ne "$Font_Cyan${smail[provider]}${smail[blocked]}$Font_Suffix\n"
fi
[[ $1 -eq 4 ]]&&echo -ne "${smail[sdnsbl]}\n"
}
get_opts() {
    local opt
    while getopts ':i:l:o:fhjnpyEM46' opt; do
        case $opt in
            4)
                (( IPV4check == 0 )) && ERRORcode=4
                IPV6check=0
                ;;
            6)
                (( IPV6check == 0 )) && ERRORcode=6
                IPV4check=0
                ;;
            f) fullIP=1 ;;
            h) mode_help=1 ;;
            i) iface=$OPTARG ;;
            j) mode_json=1 ;;
            l) YY=${OPTARG,,} ;;
            n) mode_no=1 ;;
            o)
                mode_output=1
                outputfile=$OPTARG
                [[ -z $outputfile ]] && ERRORcode=1
                ;;
            y) mode_yes=1 ;;
            E) YY=en ;;
            p|M) ;;  # Legacy flags accepted for compatibility.
            :|\?) ERRORcode=1; break ;;
        esac
    done

    [[ -n $iface ]] && CurlARG+=(--interface "$iface")
    return 0
}
clean_ansi(){
    printf '%b' "$1" | strip_ansi | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}
strip_ansi() {
    sed -E $'s/\033\\[[0-9;]*m//g'
}
factor_bool(){
local tmp_txt=""
if [[ $1 == "true" ]];then
tmp_txt+=".Factor |= . * { $3: { $2: true } } | "
elif [[ $1 == "false" ]];then
tmp_txt+=".Factor |= . * { $3: { $2: false } } | "
elif [ ${#1} -eq 2 ];then
tmp_txt+=".Factor |= . * { $3: { $2: \"$1\" } } | "
else
tmp_txt+=".Factor |= . * { $3: { $2: null } } | "
fi
[[ -z $tmp_txt ]]&&tmp_txt="null"
echo "$tmp_txt"
}
save_json(){
local head_updates=""
local basic_updates=""
local type_updates=""
local score_updates=""
local factor_updates=""
local media_updates=""
local mail_updates=""
if [ $fullIP -eq 1 ];then
head_updates+=".Head |= . + { IP: \"${IP:-null}\" } | "
else
head_updates+=".Head |= . + { IP: \"${IPhide:-null}\" } | "
fi
head_updates+=".Head |= . + { Time: \"${shead[time_raw]:-null}\" } | "
if [ $mode_lite -eq 0 ];then
basic_updates+=".Info |= . + { ASN: \"${maxmind[asn]:-null}\" } | "
basic_updates+=".Info |= . + { Organization: \"${maxmind[org]:-null}\" } | "
basic_updates+=".Info |= . + { Latitude: \"${maxmind[lat]:-null}\" } | "
basic_updates+=".Info |= . + { Longitude: \"${maxmind[lon]:-null}\" } | "
basic_updates+=".Info |= . + { DMS: \"${maxmind[dms]:-null}\" } | "
basic_updates+=".Info |= . + { Map: \"${maxmind[map]:-null}\" } | "
basic_updates+=".Info |= . + { TimeZone: \"${maxmind[timezone]:-null}\" } | "
basic_updates+=".Info |= . * { City: { Name: \"${maxmind[city]:-null}\" } } | "
basic_updates+=".Info |= . * { City: { PostalCode: \"${maxmind[post]:-null}\" } } | "
basic_updates+=".Info |= . * { City: { SubCode: \"${maxmind[subcode]:-null}\" } } | "
basic_updates+=".Info |= . * { City: { Subdivisions: \"${maxmind[sub]:-null}\" } } | "
basic_updates+=".Info |= . * { Region: { Code: \"${maxmind[countrycode]:-null}\" } } | "
basic_updates+=".Info |= . * { Region: { Name: \"${maxmind[country]:-null}\" } } | "
basic_updates+=".Info |= . * { Continent: { Code: \"${maxmind[continentcode]:-null}\" } } | "
basic_updates+=".Info |= . * { Continent: { Name: \"${maxmind[continent]:-null}\" } } | "
basic_updates+=".Info |= . * { RegisteredRegion: { Code: \"${maxmind[regcountrycode]:-null}\" } } | "
basic_updates+=".Info |= . * { RegisteredRegion: { Name: \"${maxmind[regcountry]:-null}\" } } | "
if [[ -n ${maxmind[countrycode]} && ${maxmind[countrycode]} != "null" ]];then
if [ "${maxmind[countrycode]}" == "${maxmind[regcountrycode]}" ];then
basic_updates+=".Info |= . + { Type: \"$(clean_ansi "${sbasic[type0]:-null}")\" } | "
else
basic_updates+=".Info |= . + { Type: \"$(clean_ansi "${sbasic[type1]:-null}")\" } | "
fi
else
basic_updates+='.Info |= . + { Type: "null" } | '
fi
else
basic_updates+=".Info |= . + { ASN: \"${ipinfo[asn]:-null}\" } | "
basic_updates+=".Info |= . + { Organization: \"${ipinfo[org]:-null}\" } | "
basic_updates+=".Info |= . + { Latitude: \"${ipinfo[lat]:-null}\" } | "
basic_updates+=".Info |= . + { Longitude: \"${ipinfo[lon]:-null}\" } | "
basic_updates+=".Info |= . + { DMS: \"${ipinfo[dms]:-null}\" } | "
basic_updates+=".Info |= . + { Map: \"${ipinfo[map]:-null}\" } | "
basic_updates+=".Info |= . + { TimeZone: \"${ipinfo[timezone]:-null}\" } | "
basic_updates+=".Info |= . * { City: { Name: \"${ipinfo[city]:-null}\" } } | "
basic_updates+=".Info |= . * { City: { PostalCode: \"${ipinfo[post]:-null}\" } } | "
basic_updates+='.Info |= . * { City: { SubCode: "null" } } | '
basic_updates+='.Info |= . * { City: { Subdivisions: "null" } } | '
basic_updates+=".Info |= . * { Region: { Code: \"${ipinfo[countrycode]:-null}\" } } | "
basic_updates+=".Info |= . * { Region: { Name: \"${ipinfo[country]:-null}\" } } | "
basic_updates+='.Info |= . * { Continent: { Code: "null" } } | '
basic_updates+=".Info |= . * { Continent: { Name: \"${ipinfo[continent]:-null}\" } } | "
basic_updates+=".Info |= . * { RegisteredRegion: { Code: \"${ipinfo[regcountrycode]:-null}\" } } | "
basic_updates+=".Info |= . * { RegisteredRegion: { Name: \"${ipinfo[regcountry]:-null}\" } } | "
if [[ -n ${ipinfo[countrycode]} && ${ipinfo[countrycode]} != "null" ]];then
if [ "${ipinfo[countrycode]}" == "${ipinfo[regcountrycode]}" ];then
basic_updates+=".Info |= . + { Type: \"$(clean_ansi "${sbasic[type0]:-null}")\" } | "
else
basic_updates+=".Info |= . + { Type: \"$(clean_ansi "${sbasic[type1]:-null}")\" } | "
fi
else
basic_updates+='.Info |= . + { Type: "null" } | '
fi
fi
type_updates+=".Type |= . * { Usage: { IPinfo: \"$(clean_ansi "${ipinfo[susetype]:-null}")\" } } | "
type_updates+=".Type |= . * { Usage: { ipregistry: \"$(clean_ansi "${ipregistry[susetype]:-null}")\" } } | "
type_updates+=".Type |= . * { Usage: { ipapi: \"$(clean_ansi "${ipapi[susetype]:-null}")\" } } | "
type_updates+=".Type |= . * { Usage: { AbuseIPDB: \"$(clean_ansi "${abuseipdb[susetype]:-null}")\" } } | "
type_updates+=".Type |= . * { Usage: { IP2LOCATION: \"$(clean_ansi "${ip2location[susetype]:-null}")\" } } | "
type_updates+=".Type |= . * { Company: { IPinfo: \"$(clean_ansi "${ipinfo[scomtype]:-null}")\" } } | "
type_updates+=".Type |= . * { Company: { ipregistry: \"$(clean_ansi "${ipregistry[scomtype]:-null}")\" } } | "
type_updates+=".Type |= . * { Company: { ipapi: \"$(clean_ansi "${ipapi[scomtype]:-null}")\" } } | "
type_updates+=".Type |= . * { Company: { IP2LOCATION: \"$(clean_ansi "${ip2location[scomtype]:-null}")\" } } | "
score_updates+=".Score |= . + { IP2LOCATION: \"${ip2location[score]:-null}\" } | "
score_updates+=".Score |= . + { SCAMALYTICS: \"${scamalytics[score]:-null}\" } | "
score_updates+=".Score |= . + { ipapi: \"${ipapi[score]:-null}\" } | "
score_updates+=".Score |= . + { AbuseIPDB: \"${abuseipdb[score]:-null}\" } | "
score_updates+=".Score |= . + { IPQS: \"${ipqs[score]:-null}\" } | "
score_updates+=".Score |= . + { DBIP: \"${dbip[score]:-null}\" } | "
factor_updates+=$(factor_bool "${ip2location[countrycode]}" "IP2LOCATION" "CountryCode")
factor_updates+=$(factor_bool "${ipapi[countrycode]}" "ipapi" "CountryCode")
factor_updates+=$(factor_bool "${ipregistry[countrycode]}" "ipregistry" "CountryCode")
factor_updates+=$(factor_bool "${ipqs[countrycode]}" "IPQS" "CountryCode")
factor_updates+=$(factor_bool "${scamalytics[countrycode]}" "SCAMALYTICS" "CountryCode")
factor_updates+=$(factor_bool "${ipdata[countrycode]}" "ipdata" "CountryCode")
factor_updates+=$(factor_bool "${ipinfo[countrycode]}" "IPinfo" "CountryCode")
factor_updates+=$(factor_bool "${ipwhois[countrycode]}" "IPWHOIS" "CountryCode")
factor_updates+=$(factor_bool "${dbip[countrycode]}" "DBIP" "CountryCode")
factor_updates+=$(factor_bool "${ip2location[proxy]}" "IP2LOCATION" "Proxy")
factor_updates+=$(factor_bool "${ipapi[proxy]}" "ipapi" "Proxy")
factor_updates+=$(factor_bool "${ipregistry[proxy]}" "ipregistry" "Proxy")
factor_updates+=$(factor_bool "${ipqs[proxy]}" "IPQS" "Proxy")
factor_updates+=$(factor_bool "${scamalytics[proxy]}" "SCAMALYTICS" "Proxy")
factor_updates+=$(factor_bool "${ipdata[proxy]}" "ipdata" "Proxy")
factor_updates+=$(factor_bool "${ipinfo[proxy]}" "IPinfo" "Proxy")
factor_updates+=$(factor_bool "${ipwhois[proxy]}" "IPWHOIS" "Proxy")
factor_updates+=$(factor_bool "${dbip[proxy]}" "DBIP" "Proxy")
factor_updates+=$(factor_bool "${ip2location[tor]}" "IP2LOCATION" "Tor")
factor_updates+=$(factor_bool "${ipapi[tor]}" "ipapi" "Tor")
factor_updates+=$(factor_bool "${ipregistry[tor]}" "ipregistry" "Tor")
factor_updates+=$(factor_bool "${ipqs[tor]}" "IPQS" "Tor")
factor_updates+=$(factor_bool "${scamalytics[tor]}" "SCAMALYTICS" "Tor")
factor_updates+=$(factor_bool "${ipdata[tor]}" "ipdata" "Tor")
factor_updates+=$(factor_bool "${ipinfo[tor]}" "IPinfo" "Tor")
factor_updates+=$(factor_bool "${ipwhois[tor]}" "IPWHOIS" "Tor")
factor_updates+=$(factor_bool "${dbip[tor]}" "DBIP" "Tor")
factor_updates+=$(factor_bool "${ip2location[vpn]}" "IP2LOCATION" "VPN")
factor_updates+=$(factor_bool "${ipapi[vpn]}" "ipapi" "VPN")
factor_updates+=$(factor_bool "${ipregistry[vpn]}" "ipregistry" "VPN")
factor_updates+=$(factor_bool "${ipqs[vpn]}" "IPQS" "VPN")
factor_updates+=$(factor_bool "${scamalytics[vpn]}" "SCAMALYTICS" "VPN")
factor_updates+=$(factor_bool "${ipdata[vpn]}" "ipdata" "VPN")
factor_updates+=$(factor_bool "${ipinfo[vpn]}" "IPinfo" "VPN")
factor_updates+=$(factor_bool "${ipwhois[vpn]}" "IPWHOIS" "VPN")
factor_updates+=$(factor_bool "${dbip[vpn]}" "DBIP" "VPN")
factor_updates+=$(factor_bool "${ip2location[server]}" "IP2LOCATION" "Server")
factor_updates+=$(factor_bool "${ipapi[server]}" "ipapi" "Server")
factor_updates+=$(factor_bool "${ipregistry[server]}" "ipregistry" "Server")
factor_updates+=$(factor_bool "${ipqs[server]}" "IPQS" "Server")
factor_updates+=$(factor_bool "${scamalytics[server]}" "SCAMALYTICS" "Server")
factor_updates+=$(factor_bool "${ipdata[server]}" "ipdata" "Server")
factor_updates+=$(factor_bool "${ipinfo[server]}" "IPinfo" "Server")
factor_updates+=$(factor_bool "${ipwhois[server]}" "IPWHOIS" "Server")
factor_updates+=$(factor_bool "${dbip[server]}" "DBIP" "Server")
factor_updates+=$(factor_bool "${ip2location[abuser]}" "IP2LOCATION" "Abuser")
factor_updates+=$(factor_bool "${ipapi[abuser]}" "ipapi" "Abuser")
factor_updates+=$(factor_bool "${ipregistry[abuser]}" "ipregistry" "Abuser")
factor_updates+=$(factor_bool "${ipqs[abuser]}" "IPQS" "Abuser")
factor_updates+=$(factor_bool "${scamalytics[abuser]}" "SCAMALYTICS" "Abuser")
factor_updates+=$(factor_bool "${ipdata[abuser]}" "ipdata" "Abuser")
factor_updates+=$(factor_bool "${ipinfo[abuser]}" "IPinfo" "Abuser")
factor_updates+=$(factor_bool "${ipwhois[abuser]}" "IPWHOIS" "Abuser")
factor_updates+=$(factor_bool "${dbip[abuser]}" "DBIP" "Abuser")
factor_updates+=$(factor_bool "${ip2location[robot]}" "IP2LOCATION" "Robot")
factor_updates+=$(factor_bool "${ipapi[robot]}" "ipapi" "Robot")
factor_updates+=$(factor_bool "${ipregistry[robot]}" "ipregistry" "Robot")
factor_updates+=$(factor_bool "${ipqs[robot]}" "IPQS" "Robot")
factor_updates+=$(factor_bool "${scamalytics[robot]}" "SCAMALYTICS" "Robot")
factor_updates+=$(factor_bool "${ipdata[robot]}" "ipdata" "Robot")
factor_updates+=$(factor_bool "${ipinfo[robot]}" "IPinfo" "Robot")
factor_updates+=$(factor_bool "${ipwhois[robot]}" "IPWHOIS" "Robot")
factor_updates+=$(factor_bool "${dbip[robot]}" "DBIP" "Robot")
media_updates+=".Media |= . * { TikTok: { Status: \"$(clean_ansi "${tiktok[ustatus]:-null}")\" } } | "
media_updates+=".Media |= . * { DisneyPlus: { Status: \"$(clean_ansi "${disney[ustatus]:-null}")\" } } | "
media_updates+=".Media |= . * { Netflix: { Status: \"$(clean_ansi "${netflix[ustatus]:-null}")\" } } | "
media_updates+=".Media |= . * { Youtube: { Status: \"$(clean_ansi "${youtube[ustatus]:-null}")\" } } | "
media_updates+=".Media |= . * { AmazonPrimeVideo: { Status: \"$(clean_ansi "${amazon[ustatus]:-null}")\" } } | "
media_updates+=".Media |= . * { Claude: { Status: \"$(clean_ansi "${claude[ustatus]:-null}")\" } } | "
media_updates+=".Media |= . * { ChatGPT: { Status: \"$(clean_ansi "${chatgpt[ustatus]:-null}")\" } } | "
media_updates+=".Media |= . * { TikTok: { Region: \"$(clean_ansi "${tiktok[uregion]//[][]/}")\" } } | "
media_updates+=".Media |= . * { DisneyPlus: { Region: \"$(clean_ansi "${disney[uregion]//[][]/}")\" } } | "
media_updates+=".Media |= . * { Netflix: { Region: \"$(clean_ansi "${netflix[uregion]//[][]/}")\" } } | "
media_updates+=".Media |= . * { Youtube: { Region: \"$(clean_ansi "${youtube[uregion]//[][]/}")\" } } | "
media_updates+=".Media |= . * { AmazonPrimeVideo: { Region: \"$(clean_ansi "${amazon[uregion]//[][]/}")\" } } | "
media_updates+=".Media |= . * { Claude: { Region: \"$(clean_ansi "${claude[uregion]//[][]/}")\" } } | "
media_updates+=".Media |= . * { ChatGPT: { Region: \"$(clean_ansi "${chatgpt[uregion]//[][]/}")\" } } | "
media_updates+=".Media |= . * { TikTok: { Type: \"$(clean_ansi "${tiktok[utype]:-null}")\" } } | "
media_updates+=".Media |= . * { DisneyPlus: { Type: \"$(clean_ansi "${disney[utype]:-null}")\" } } | "
media_updates+=".Media |= . * { Netflix: { Type: \"$(clean_ansi "${netflix[utype]:-null}")\" } } | "
media_updates+=".Media |= . * { Youtube: { Type: \"$(clean_ansi "${youtube[utype]:-null}")\" } } | "
media_updates+=".Media |= . * { AmazonPrimeVideo: { Type: \"$(clean_ansi "${amazon[utype]:-null}")\" } } | "
media_updates+=".Media |= . * { Claude: { Type: \"$(clean_ansi "${claude[utype]:-null}")\" } } | "
media_updates+=".Media |= . * { ChatGPT: { Type: \"$(clean_ansi "${chatgpt[utype]:-null}")\" } } | "
if [[ ${smail[local]} -eq 1 ]];then
mail_updates+=".Mail |= . + { Port25: true } | "
for service in "${services[@]}";do
if [[ ${smailstatus[$service]} == "true" ]];then
mail_updates+=".Mail |= . + { \"$service\": true } | "
else
mail_updates+=".Mail |= . + { \"$service\": false } | "
fi
done
elif [[ ${smail[local]} -eq 2 ]];then
mail_updates+=".Mail |= . + { Port25: null } | "
for service in "${services[@]}";do
mail_updates+=".Mail |= . + { \"$service\": null } | "
done
else
mail_updates+=".Mail |= . + { Port25: false } | "
for service in "${services[@]}";do
mail_updates+=".Mail |= . + { \"$service\": false } | "
done
fi
mail_updates+=".Mail |= . * { DNSBlacklist: { Total: ${smail[t]:-null} } } | "
mail_updates+=".Mail |= . * { DNSBlacklist: { Clean: ${smail[c]:-null} } } | "
mail_updates+=".Mail |= . * { DNSBlacklist: { Marked: ${smail[m]:-null} } } | "
mail_updates+=".Mail |= . * { DNSBlacklist: { Blacklisted: ${smail[b]:-null} } } | "
ipjson=$(echo "$ipjson"|jq "$head_updates$basic_updates$type_updates$score_updates$factor_updates$media_updates$mail_updates.")
}
check_IP(){
local ip_report family=$2 stages=4
[[ $family != 4 ]] || stages=5
local db="[IPv$family 1/$stages] ${sprogress[db]}"
local media="[IPv$family 2/$stages] ${sprogress[media]}"
IP=$1
ipjson='{
      "Head": {},
      "Info": {},
      "Type": {},
      "Score": {},
      "Factor": {},
      "Media": {},
      "Mail": {}
    }'
[[ $2 -eq 4 ]]&&hide_ipv4 $IP
[[ $2 -eq 6 ]]&&hide_ipv6 $IP
run_probe "$db · MaxMind" db_maxmind "$family"
run_probe "$db · IPinfo" db_ipinfo
fill_basic_location
[[ $mode_lite -eq 0 ]] && run_probe "$db · Scamalytics" db_scamalytics "$family" || scamalytics=()
run_probe "$db · IPregistry" db_ipregistry "$family"
run_probe "$db · ipapi" db_ipapi "$family"
[[ $mode_lite -eq 0 ]] && run_probe "$db · AbuseIPDB" db_abuseipdb "$family" || abuseipdb=()
[[ $mode_lite -eq 0 ]] && run_probe "$db · IP2Location" db_ip2location "$family" || ip2location=()
run_probe "$db · DB-IP" db_dbip
[[ $mode_lite -eq 0 ]] && run_probe "$db · ipdata" db_ipdata "$family" || ipdata=()
[[ $mode_lite -eq 0 ]] && run_probe "$db · IPQS" db_ipqs "$family" || ipqs=()
run_probe "$media · TikTok (1/7)" MediaUnlockTest_TikTok "$family"
run_probe "$media · Disney+ (2/7)" MediaUnlockTest_DisneyPlus "$family"
run_probe "$media · Netflix (3/7)" MediaUnlockTest_Netflix "$family"
run_probe "$media · YouTube (4/7)" MediaUnlockTest_YouTube_Premium "$family"
run_probe "$media · Prime Video (5/7)" MediaUnlockTest_PrimeVideo_Region "$family"
run_probe "$media · Claude (6/7)" MediaUnlockTest_Claude "$family"
run_probe "$media · ChatGPT (7/7)" OpenAITest "$family"
check_mail "[IPv$family 3/$stages] ${sprogress[mail]}"
if [[ $family == 4 ]]; then
    check_dnsbl "$IP" 50 "[IPv4 4/$stages] ${sprogress[dnsbl]}"
fi
progress "[IPv$family $stages/$stages] ${sprogress[report]}"
if [[ $mode_lite -eq 0 ]];then
ip_report=$(show_head
show_basic
show_type
show_score
show_factor
show_media
show_mail "$2")
else
ip_report=$(show_head
show_basic_lite
show_type_lite
show_score
show_factor_lite
show_media
show_mail "$2")
fi
if [[ $mode_json -eq 1 || ( $mode_output -eq 1 && $outputfile == *.[jJ][sS][oO][nN] ) ]];then
save_json || return
fi
if [[ $mode_json -eq 1 ]];then
printf '%s\n' "$ipjson"
elif (( terminal_page )); then
terminal_reports+=("$ip_report")
else
printf '%s\n\n' "$ip_report"
fi
if [[ mode_output -eq 1 ]];then
case "$outputfile" in
*.[aA][nN][sS][iI])printf '%s\n' "$ip_report" >>"$outputfile"
;;
*.[jJ][sS][oO][nN])printf '%s\n' "$ipjson" >>"$outputfile"
;;
*)printf '%s\n' "$ip_report" | strip_ansi >>"$outputfile"
esac
fi
}

prepare_output() {
    if [[ -e $outputfile || -L $outputfile ]]; then
        printf '%s\n' "${swarn[10]}" >&2
        return 10
    fi
    if (set -o noclobber; : > "$outputfile") 2>/dev/null; then
        return 0
    fi
    printf '%s\n' "${swarn[11]}" >&2
    return 11
}

main() {
    get_opts "$@"
    case $YY in
        cn|en|jp|es|de|fr|ru|pt) set_language ;;
        *) printf 'Unsupported language: %s\n' "$YY" >&2; return 1 ;;
    esac
    if (( ERRORcode != 0 )); then
        printf '%s\n' "${swarn[$ERRORcode]}" >&2
        return "$ERRORcode"
    fi
    if (( mode_help )); then
        print_help
        return 0
    fi
    open_terminal_page
    if (( mode_no == 0 )); then
        progress "${sprogress[deps]}"
        install_dependencies >&2 || return
    fi

    if (( IPV4check )); then
        run_probe "IPv4 · ${sprogress[egress]}" get_ipv4
        is_valid_ipv4 "$IPV4"
    fi
    if (( IPV6check )); then
        run_probe "IPv6 · ${sprogress[egress]}" get_ipv6
        is_valid_ipv6 "$IPV6"
    fi
    progress
    if (( IPV4work == 0 && IPV6work == 0 )); then
        if [[ -n $iface ]]; then
            ERRORcode=7
        elif (( IPV6check == 0 )); then
            ERRORcode=40
        elif (( IPV4check == 0 )); then
            ERRORcode=60
        else
            ERRORcode=46
        fi
        printf '%s\n' "${swarn[$ERRORcode]}" >&2
        return "$ERRORcode"
    fi
    if (( mode_output )); then
        prepare_output || return
    fi

    generate_random_user_agent
    adapt_locale
    run_probe "${sprogress[country]}" load_country_data
    if (( IPV4work )); then
        check_IP "$IPV4" 4 || return
    fi
    if (( IPV6work )); then
        check_IP "$IPV6" 6 || return
    fi
    if (( terminal_page )); then
        view_terminal_reports
    fi
}

if [[ ${BASH_SOURCE[0]:-$0} == "$0" ]]; then
    trap cleanup_run EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    main "$@"
    result=$?
    if (( result != 0 && terminal_page )); then
        printf '\n%s' "${sprogress[close]}" >&2
        IFS= read -rsn1 _ || :
    fi
    exit "$result"
fi
