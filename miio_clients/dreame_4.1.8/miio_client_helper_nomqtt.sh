#!/bin/sh
#
# version: 4.1.6
# date: 2021/02/26
#
# set -x
source /usr/bin/config

WIFI_CONF_PATH="/etc/miio/wifi.conf"
WIFI_START_SCRIPT="/usr/bin/wifi_start.sh"
MIIO_RECV_LINE="/usr/bin/miio_recv_line"
MIIO_SEND_LINE="/usr/bin/miio_send_line"
JSHON="/usr/bin/jshon"
#WIFI_NODE="wlan0"
WIFI_MAX_RETRY=5
WIFI_RETRY_INTERVAL=3
WIFI_SSID=
#PIN_CODE_MODE=[2 3]
#PIN_CODE_LEN=[4 6]

GLIBC_TIMEZONE_DIR="/usr/share/zoneinfo"
UCLIBC_TIMEZONE_DIR="/usr/share/zoneinfo/uclibc"

LINK_TIMEZONE_FILE="/data/config/system/localtime"
TIMEZONE_DIR="/usr/share/zoneinfo"
MIIO_TOKEN_FILE=

if [ "$MIIO_AUTO_OTA" == "true" ]; then
    auto_ota=true
else
    auto_ota=false
fi

if [ -z "$WIFI_NODE" ]; then
   WIFI_NODE="wlan0"
fi

# contains(string, substring)
#
# Returns 0 if the specified string contains the specified substring,
# otherwise returns 1.
contains() {
    string="$1"
    substring="$2"
    if test "${string#*$substring}" != "$string"
    then
        return 0    # $substring is in $string
    else
        return 1    # $substring is not in $string
    fi
}

send_helper_ready() {
    ready_msg="{\"method\":\"_internal.helper_ready\"}"
    log "$ready_msg"
    $MIIO_SEND_LINE "$ready_msg"
}

set_wifi_down() {
    STRING=`ifconfig ${WIFI_NODE} down`
    REQ_WIFI_DOWN_STATUS_RESPONSE="{\"method\":\"_internal.res_wifi_down\",\"params\":1}"
}

set_wifi_up() {
    STRING=`ifconfig ${WIFI_NODE} up`
    REQ_WIFI_UP_STATUS_RESPONSE="{\"method\":\"_internal.res_wifi_up\",\"params\":1}"
}

req_wifi_conf_status() {
    wificonf_dir=$1
    wificonf_dir=${wificonf_dir##*params\":\"}
    wificonf_dir=${wificonf_dir%%\"*}
    wificonf_dir=`echo $wificonf_dir | xargs echo`
    wificonf_file=${wificonf_dir}/wifi.conf
    #log "$wificonf_file"

    REQ_WIFI_CONF_STATUS_RESPONSE=""
    if [ -e $wificonf_file ]; then
        WIFI_SSID=`cat $wificonf_file | grep ssid`
        WIFI_SSID=${WIFI_SSID#*ssid=\"}
        WIFI_SSID=${WIFI_SSID%\"*}
        WIFI_SSID=${WIFI_SSID//\\/\\\\}
        WIFI_SSID=${WIFI_SSID//\"/\\\"}
        log "WIFI_SSID: $WIFI_SSID"

        WIFI_PSK=`cat $wificonf_file | grep psk`
        WIFI_PSK=${WIFI_PSK#*psk=\"}
        WIFI_PSK=${WIFI_PSK%\"*}
        WIFI_PSK=${WIFI_PSK//\\/\\\\}
        WIFI_PSK=${WIFI_PSK//\"/\\\"}
        log "WIFI_PSK: $WIFI_PSK"

        REQ_WIFI_CONF_STATUS_RESPONSE="{\"method\":\"_internal.res_wifi_conf_status\",\"params\":1,\"ssid\":\"$WIFI_SSID\",\"psk\":\"$WIFI_PSK\"}"
    else
        REQ_WIFI_CONF_STATUS_RESPONSE="{\"method\":\"_internal.res_wifi_conf_status\",\"params\":0}"
    fi
}

request_dinfo() {
    # del all msq queue, or cause unexpected issues
    rm -f  /dev/mqueue/miio_queue*

    let req_dinfo_cnt++
    [ $req_dinfo_cnt -ge 100 ] && {
        record_events.sh iot_error 1001;
        killall -9 miio_client;
    }

    dinfo_dir=$1
    dinfo_dir=${dinfo_dir##*params\":\"}
    dinfo_dir=${dinfo_dir%%\"*}
    dinfo_dir=`echo $dinfo_dir | xargs echo`
    dinfo_file=${dinfo_dir}/device.conf

    dinfo_did=`cat $dinfo_file | grep -v ^# | grep did= | tail -1 | cut -d '=' -f 2`
    if [ -f ${DM_FLAG} ]; then
        dinfo_key=`${NA_RELEASE} -c 2 -m MI_KEY | grep "MI_KEY:" | awk -F ':' '{print $2}'`
    else
        dinfo_key=`cat $dinfo_file | grep -v ^# | grep key= | tail -1 | cut -d '=' -f 2`
    fi
    dinfo_mjac_i2c=`cat $dinfo_file | grep -v ^# | grep mjac_i2c= | tail -1 | cut -d '=' -f 2`
    dinfo_mjac_gpio=`cat $dinfo_file | grep -v ^# | grep mjac_gpio= | tail -1 | cut -d '=' -f 2`
    dinfo_vendor=`cat $dinfo_file | grep -v ^# | grep vendor= | tail -1 | cut -d '=' -f 2`
    dinfo_mac=`cat $dinfo_file | grep -v ^# | grep mac= | tail -1 | cut -d '=' -f 2`
    dinfo_model=`cat $dinfo_file | grep -v ^# | grep model= | tail -1 | cut -d '=' -f 2`
    RESPONSE_DINFO="{\"method\":\"_internal.response_dinfo\",\"params\":{"
    if [ x$dinfo_mjac_i2c != x ]; then
        RESPONSE_DINFO="$RESPONSE_DINFO\"mjac_i2c\":\"$dinfo_mjac_i2c\""
        if [ x$dinfo_mjac_gpio != x ]; then
            RESPONSE_DINFO="$RESPONSE_DINFO,\"mjac_gpio\":\"$dinfo_mjac_gpio\""
        fi
    else
        if [ x$dinfo_did != x ]; then
            RESPONSE_DINFO="$RESPONSE_DINFO\"did\":$dinfo_did"
        fi
        if [ x$dinfo_key != x ]; then
            RESPONSE_DINFO="$RESPONSE_DINFO,\"key\":\"$dinfo_key\""
        fi
    fi
    if [ x$dinfo_vendor != x ]; then
        RESPONSE_DINFO="$RESPONSE_DINFO,\"vendor\":\"$dinfo_vendor\""
    fi
    if [ x$dinfo_mac != x ]; then
        RESPONSE_DINFO="$RESPONSE_DINFO,\"mac\":\"$dinfo_mac\""
    fi
    if [ x$dinfo_model != x ]; then
        RESPONSE_DINFO="$RESPONSE_DINFO,\"model\":\"$dinfo_model\""
    fi
    if [ x$dinfo_bootloader_ver != x ]; then
        RESPONSE_DINFO="$RESPONSE_DINFO,\"bootloader_ver\":\"$dinfo_bootloader_ver\""
    fi
    if [ x$dinfo_qrcode != x ]; then
        RESPONSE_DINFO="$RESPONSE_DINFO,\"OOB\":[{\"mode\":3,\"ctx\":\"$dinfo_qrcode\"},{\"mode\":2,\"ctx\":\"\"}]"
    fi
        RESPONSE_DINFO="$RESPONSE_DINFO,\"sc_type\":[0,1,2,3,4,16]"
    RESPONSE_DINFO="$RESPONSE_DINFO}}"
}

request_dtoken() {
    dtoken_string=$1
    dtoken_dir=${dtoken_string##*dir\":\"}
    dtoken_dir=${dtoken_dir%%\"*}
    dtoken_dir=`echo $dtoken_dir | xargs echo`
    dtoken_token=${dtoken_string##*ntoken\":\"}
    dtoken_token=${dtoken_token%%\"*}
    log "$dtoken_dir"

    MIIO_TOKEN_FILE=${dtoken_dir}/device.token
    dcountry_file=${dtoken_dir}/device.country

    if [ ! -e ${dtoken_dir}/wifi.conf ]; then
        rm -f ${MIIO_TOKEN_FILE}
    fi

    if [ -e ${MIIO_TOKEN_FILE} ]; then
        dtoken_token=`cat ${MIIO_TOKEN_FILE}`
    else
        echo ${dtoken_token} > ${MIIO_TOKEN_FILE}
    fi
    
    if [ -e ${dcountry_file} ]; then
        dcountry_country=`cat ${dcountry_file}`
    else
        dcountry_country=""
    fi
    improve_program=0 #judge whether to upload,If you want to upload offline info, set to 1
    offline_time=0 #assign by record value, if not exsit, ignore it
    offline_reason=0 #assign by record value, if not exsit, ignore it
    offline_ip=0 #assign by record value, if not exsit, ignore it
    offline_port=0 #assign by record value, if not exsit, ignore it

    RESPONSE_DTOKEN="{\"method\":\"_internal.response_dtoken\",\"params\":\"${dtoken_token}\"}"
    RESPONSE_DCOUNTRY="{\"method\":\"_internal.response_dcountry\",\"params\":\"${dcountry_country}\"}"
    RESPONSE_OFFLINE="{\"method\":\"_internal.response_offline\",\"params\":{\"offline_time\":${offline_time},\"offline_reason\":${offline_reason},\"improve_program\":${improve_program},\"offline_ip\":${offline_ip},\"offline_port\":${offline_port}}}"
}

request_ot_config() {
    ot_config_string=$1

    ot_config_dir=${ot_config_string##*dir\":\"}
    ot_config_dir=${ot_config_dir%%\"*}

    dtoken_token=${ot_config_string##*ntoken\":\"}
    dtoken_token=${dtoken_token%%\"*}

    MIIO_TOKEN_FILE="${ot_config_dir}device.token"
    dcountry_file="${ot_config_dir}device.country"
    wificonf_file="${ot_config_dir}wifi.conf"
    uid_file="${ot_config_dir}device.uid"

    if [ ! -e "${ot_config_dir}wifi.conf" ]; then
        rm -f ${MIIO_TOKEN_FILE}
        rm -f ${dcountry_file}
        rm -f ${uid_file}
    fi

    if [ -e ${MIIO_TOKEN_FILE} ]; then
        dtoken_token=`cat ${MIIO_TOKEN_FILE}`
    else
        echo ${dtoken_token} > ${MIIO_TOKEN_FILE}
    fi

    dcountry_country=`cat ${dcountry_file}`
    uid=`cat ${uid_file}`

    WIFI_SSID=`cat $wificonf_file | grep ssid`
    WIFI_SSID=${WIFI_SSID#*ssid=\"}
    WIFI_SSID=${WIFI_SSID%\"*}
    WIFI_SSID=${WIFI_SSID//\\/\\\\}
    WIFI_SSID=${WIFI_SSID//\"/\\\"}
    log "WIFI_SSID: $WIFI_SSID"

    WIFI_PSK=`cat $wificonf_file | grep psk`
    WIFI_PSK=${WIFI_PSK#*psk=\"}
    WIFI_PSK=${WIFI_PSK%\"*}
    WIFI_PSK=${WIFI_PSK//\\/\\\\}
    WIFI_PSK=${WIFI_PSK//\"/\\\"}
    log "WIFI_PSK: $WIFI_PSK"


    RESPONSE_OT_CONFIG="{\"method\":\"_internal.res_ot_config\",\"params\":{"
    RESPONSE_OT_CONFIG="$RESPONSE_OT_CONFIG\"token\":\"$dtoken_token\""
    if [ x$dcountry_country != x ]; then
        RESPONSE_OT_CONFIG="$RESPONSE_OT_CONFIG,\"country\":\"$dcountry_country\""
    fi
    if [ x$WIFI_SSID != x ]; then
        RESPONSE_OT_CONFIG="$RESPONSE_OT_CONFIG,\"ssid\":\"$WIFI_SSID\""
    fi
    if [ x$WIFI_PSK != x ]; then
        RESPONSE_OT_CONFIG="$RESPONSE_OT_CONFIG,\"password\":\"$WIFI_PSK\""
    fi
    if [ x$uid != x ]; then
        RESPONSE_OT_CONFIG="$RESPONSE_OT_CONFIG,\"uid\":$uid"
    fi
    RESPONSE_OT_CONFIG="$RESPONSE_OT_CONFIG}}"
}

update_dtoken(){
    update_token_string=$1
    update_dtoken=${update_token_string##*ntoken\":\"}
    update_token=${update_dtoken%%\"*}

    if [ -e ${MIIO_TOKEN_FILE} ]; then
        rm -rf ${MIIO_TOKEN_FILE}
        echo ${update_token} > ${MIIO_TOKEN_FILE}
        RESPONSE_UPDATE_TOKEN="{\"method\":\"_internal.token_updated\",\"params\":\"${update_token}\"}"
    fi
}

save_wifi_conf() {
    datadir=$1
    miio_ssid=$2
    miio_passwd=$3
    miio_uid=$4
    miio_country=$5
	
	datadir=`echo $datadir | xargs echo`
	rm -f $datadir/wifi.conf
	
	echo "ssid=\"$miio_ssid\"" > $datadir/wifi.conf
    if [ x"$miio_passwd" = x ]; then
        miio_key_mgmt="NONE"
    else
        LEN=`echo "${miio_passwd}" | awk '{print length($0)}'`
        if [ ${LEN} -lt 8 ]; then
            SSID="${SSID}" STATE="PWD_ERROR" /usr/bin/wifi_state.sh &
            log "pwd is too short:${LEN}"
            return 1
        fi

        miio_key_mgmt="WPA"

        case "$PRODUCT_NAME" in
          r2216|r2257)
            wpa_passphrase "$miio_ssid" "$miio_passwd" > /tmp/psk.log
            if [ $? -eq 0 ]; then
                miio_passwd=`grep -v "#psk" /tmp/psk.log | grep "psk" | awk '{print $1}'`
                miio_passwd=${miio_passwd#*psk=}
                echo "psk=$miio_passwd" >> $datadir/wifi.conf
            fi
          ;;

          *)
            echo "psk=\"$miio_passwd\"" >> $datadir/wifi.conf
          ;;
        esac

    fi

    echo "key_mgmt=$miio_key_mgmt" >> $datadir/wifi.conf
    if [ $miio_uid -ne 0 ]; then
        echo "uid=$miio_uid" >> $datadir/wifi.conf
    fi
    echo "$miio_uid" > $datadir/device.uid
    echo "$miio_country" > $datadir/device.country
    return 0
}

clear_wifi_conf() {
    datadir=$1
    rm -f $datadir/wifi.conf
    rm -f $datadir/device.uid
    rm -f $datadir/device.country
}

wifi_reassociate()
{
    newwork_id=`wpa_cli -i $ifname list_network | grep $ssid | cut -f 1`
    wpa_cli -i $ifname set_network $newwork_id bssid $1
    wpa_cli -i $ifname disable_network $newwork_id
    wpa_cli -i $ifname enable_network $newwork_id
} 

wifi_scan()
{
    for i in 1 2 3; do
        bssid_search=`wpa_cli -i $ifname scan`
        if [ "$bssid_search" == "OK" ]; then
            sleep 2
            wifi_choose
            break
        else
            log "scan error for $i times"
            sleep 2
        fi
    done
    if [ "$bssid_search" != "OK" ]; then
        reassociate_status="scan error"
        bbssid=""
    fi
}

wifi_choose()
{
    bbssid=`wpa_cli -i $ifname scan_result | grep $ssid | sort -n -r -k 3 | cut -f 1 | head -1`
    log "best bssid is $bbssid"
    bssid_old=` wpa_cli status |grep bssid | cut -d '=' -f 2`
    if [ $bbssid == $bssid_old ];then
        reassociate_status="best bssid already connected" 
    else
        wifi_reassociate $bbssid
        reassociate_status="wifi reassociate" 
    fi
}

wifi_reload()
{
    ifconfig $ifname down
    ifconfig $ifname up
    sleep 2
}

save_tz_conf() {
    if contains "$1" "../"; then
        return 0
    fi
    new_tz=$TIMEZONE_DIR/$1
    if [ -f "$new_tz" ]; then
        unlink $LINK_TIMEZONE_FILE
        ln -sf  $new_tz $LINK_TIMEZONE_FILE
        log "timezone set success:$new_tz"
    else
        log "timezone is not exist:$new_tz"
    fi
    avacmd msg_cvt '{"type":"msgCvt","cmd":"config_tz"}' &
}

sanity_check() {
    if [ ! -e $WIFI_START_SCRIPT ]; then
        log "Can't find wifi_start.sh: $WIFI_START_SCRIPT"
        log "Please change $WIFI_START_SCRIPT"
        exit 1
    fi
}

main() {
    IOT_TYPE=miiot
    if [ ! -f $IOT_FLAG ]; then
        touch $IOT_FLAG
    fi
    while true; do
    BUF=`$MIIO_RECV_LINE`
    if [ $? -ne 0 ]; then
        sleep 1;
        continue
    fi

    echo "$BUF" | grep -q '_internal.wifi_start'
    if [ $? -ne 0 ]; then
        log "receive:  $BUF"
    fi

    if contains "$BUF" "_internal.setwifidown"; then
        log "Got _internal.setwifidown"
        set_wifi_down "$BUF"
        log $REQ_WIFI_DOWN_STATUS_RESPONSE
        $MIIO_SEND_LINE "$REQ_WIFI_DOWN_STATUS_RESPONSE"
    fi

    if contains "$BUF" "_internal.setwifiup"; then
        log "Got _internal.setwifiup"
        set_wifi_up "$BUF"
        log $REQ_WIFI_UP_STATUS_RESPONSE
        $MIIO_SEND_LINE "$REQ_WIFI_UP_STATUS_RESPONSE"
    fi

    if contains "$BUF" "_internal.setwifiap"; then
        log "Got _internal.setwifiap"
        msg="{\"method\":\"_internal.wifi_ap_mode\",\"params\":null}";
        log $msg
        $MIIO_SEND_LINE "$msg"
    fi
    if contains "$BUF" "_internal.info"; then
        STRING=`wpa_cli status`

        ifname=${STRING#*\'}
        ifname=${ifname%%\'*}
# test linux pc
        #ifname=$WIFI_NODE
        #log "ifname: $ifname"

        ssid=`wpa_cli status | grep -w '^ssid'`
        ssid=${ssid#*ssid=}
        ssid=$(echo -e "$ssid" | sed -e 's/\\/\\\\/g' -e 's/\\\\\"/\\\"/g')
        if [[ -z "${ssid}" ]]; then
            if [ "x$WIFI_SSID" != "x" ]; then
                ssid=${WIFI_SSID}
            else
                if [ -e $WIFI_CONF_PATH ]; then
                    STRING_SSID=`cat $WIFI_CONF_PATH | grep ^ssid`
                    ssid=${STRING_SSID##*ssid=\"}
                    ssid=${ssid%%\"*}
                    ssid=${ssid//\\/\\\\}
                    ssid=${ssid//\"/\\\"}
                fi
            fi
        fi
        #log "ssid: $ssid"

        bssid=`wpa_cli status | grep -w '^bssid' | awk -F "=" '{print $NF}'`
        bssid=`echo ${bssid} | tr '[:lower:]' '[:upper:]'`
        #log "bssid: $bssid"

        if ! test -z $ifname
        then
           wifi_choose
           STRING=`wpa_cli status`
        fi

        rssi=`iw ${WIFI_NODE} link | grep signal | cut -d ' ' -f 2`
        if [ "x$rssi" = "x" ]; then
            rssi=0
        fi
        freq=`iw ${WIFI_NODE} link | grep freq | cut -d ' ' -f 2`
        if [ "x$freq" = "x" ]; then
            freq=0
        fi
        #log "rssi: $rssi freq: $freq"

        ip=${STRING##*ip_address=}
        ip=`echo ${ip} | cut -d ' ' -f 1`
        if [ x"$ip" = x"Selected" ]; then
            ip=
        fi
        #log "ip: $ip"

        STRING=`ifconfig ${WIFI_NODE}`
        echo "${STRING}" | grep -q Mask
        if [ $? -eq 0 ]; then
            netmask=${STRING##*Mask:}
            netmask=`echo ${netmask} | cut -d ' ' -f 1`
        else
            netmask=
        fi
        #log "netmask: $netmask"

        gw=`route -n|grep 'UG'|tr -s ' ' | cut -f 2 -d ' '`
        #log "gw: $gw"

        # get vendor and then version
        vendor=`grep "vendor" /etc/miio/device.conf | cut -f 2 -d '=' | tr '[:lower:]' '[:upper:]'`
        sw_version=`jsonpath -i /etc/os-release -e "$.fw_arm_ver"`
        if [ -z $sw_version ]; then
            sw_version="unknown"
        fi

        msg="{\"method\":\"_internal.info\",\"partner_id\":\"\",\"params\":{\
\"hw_ver\":\"Linux\",\"fw_ver\":\"$sw_version\",\"auto_ota\":$auto_ota,\
\"ap\":{\
 \"ssid\":\"$ssid\",\"bssid\":\"$bssid\",\"rssi\":\"$rssi\",\"freq\":$freq\
},\
\"netif\":{\
 \"localIp\":\"$ip\",\"mask\":\"$netmask\",\"gw\":\"$gw\"\
}}}"

        [ -n "$ip" ] && log "$msg"
        $MIIO_SEND_LINE "$msg"
    elif contains "$BUF" "_internal.req_wifi_conf_status"; then
        log "Got _internal.req_wifi_conf_status"
        req_wifi_conf_status "$BUF"
        log "$REQ_WIFI_CONF_STATUS_RESPONSE"
        $MIIO_SEND_LINE "$REQ_WIFI_CONF_STATUS_RESPONSE"
    elif contains "$BUF" "_internal.wifi_start"; then
        # TODO: add lock to /data/config/ava/iot.flag
        content=`cat $IOT_FLAG`
        if [ "x$content" == "x" ]; then
            echo $IOT_TYPE > $IOT_FLAG
            log "set SDK($content) to $IOT_FLAG"
        elif [ "x$content" != "x$IOT_TYPE" ];then
            log "other SDK($content) already set $IOT_FLAG"
            continue
        else
            log "already set current SDK($content) to $IOT_FLAG"
        fi
        wificonf_dir2=$(echo "$BUF" | $JSHON -e params -e datadir -u)
        miio_ssid=$(echo "$BUF" | $JSHON -e params -e ssid -u)
        miio_passwd=$(echo "$BUF" | $JSHON -e params -e passwd -u)
        miio_uid=$(echo "$BUF" | $JSHON -e params -e uid -u)
        miio_country=$(echo "$BUF" | $JSHON -e params -e country_domain -u)
        miio_tz=$(echo "$BUF" | $JSHON -e params -e tz -u)

        log "miio_ssid: $miio_ssid"
        log "miio_country: $miio_country"
        log "miio_tz: $miio_tz"

        save_wifi_conf "$wificonf_dir2" "$miio_ssid" "$miio_passwd" "$miio_uid" "$miio_country"
        if [ $? -eq 1 ]; then
            msg="{\"method\":\"_internal.wifi_connected\"}"
            $MIIO_SEND_LINE "$msg"
            continue
        fi
        save_tz_conf "$miio_tz"

        CMD=$WIFI_START_SCRIPT
        RETRY=1
        WIFI_SUCC=1
        until [ $RETRY -gt $WIFI_MAX_RETRY ]
        do
            WIFI_SUCC=1
            log "Retry $RETRY: CMD=${CMD}"
            ${CMD} && break
            WIFI_SUCC=0

            if [ $WIFI_MAX_RETRY -eq 1 ]; then
                break
            fi
            let RETRY=$RETRY+1
            sleep $WIFI_RETRY_INTERVAL
        done

        if [ $WIFI_SUCC -eq 1 ]; then
            msg="{\"method\":\"_internal.wifi_connected\"}"
            log "$msg"
            $MIIO_SEND_LINE "$msg"
        else
            clear_wifi_conf $wificonf_dir2
            CMD=$WIFI_START_SCRIPT
            log "Back to AP mode, CMD=${CMD}"
            ${CMD}
            msg="{\"method\":\"_internal.wifi_ap_mode\",\"params\":null}";
            log "$msg"
            $MIIO_SEND_LINE "$msg"
        fi
    elif contains "$BUF" "_internal.request_dinfo"; then
        log "Got _internal.request_dinfo"
        log "$BUF"
        request_dinfo "$BUF"
        log "$RESPONSE_DINFO"
        $MIIO_SEND_LINE "$RESPONSE_DINFO"
    elif contains "$BUF" "_internal.wifi_reload"; then
        log "Got _internal.wifi_reload"
        wifi_reload 
        wifi_choose
        REQ_WIFI_RELOAD_RESPONSE="{\"method\":\"_internal.res_wifi_reload\",\"params\":{\"wifi_reload_result\":\"$reassociate_status\",\
\"bssid\":\"$bbssid\"}}"
        log $REQ_WIFI_RELOAD_RESPONSE
        $MIIO_SEND_LINE "$REQ_WIFI_RELOAD_RESPONSE"
    elif contains "$BUF" "_internal.wifi_reconnect"; then
        echo "Got _internal.wifi_reconnect"
        wifi_scan
        REQ_WIFI_RECONNECT_RESPONSE="{\"method\":\"_internal.res_wifi_reconnect\",\"params\":{\"wifi_reconnect_result\":\"$reassociate_status\",\
\"bssid\":\"$bbssid\"}}"
        echo $REQ_WIFI_RECONNECT_RESPONSE
        $MIIO_SEND_LINE "$REQ_WIFI_RECONNECT_RESPONSE"
    elif contains "$BUF" "_internal.request_dtoken"; then
        log "Got _internal.request_dtoken"
        log "$BUF"
        request_dtoken "$BUF"
        log "$RESPONSE_DCOUNTRY"
        $MIIO_SEND_LINE "$RESPONSE_DCOUNTRY"
        log "$RESPONSE_OFFLINE"
        $MIIO_SEND_LINE "$RESPONSE_OFFLINE"
        log $RESPONSE_DTOKEN
        $MIIO_SEND_LINE "$RESPONSE_DTOKEN"
    elif contains "$BUF" "_internal.request_ot_config"; then
        log "Got _internal.request_ot_config"
        request_ot_config "$BUF"
        log $RESPONSE_OT_CONFIG
        $MIIO_SEND_LINE "$RESPONSE_OT_CONFIG"
    elif contains "$BUF" "_internal.update_dtoken"; then
        update_dtoken "$BUF"
        $MIIO_SEND_LINE "$RESPONSE_UPDATE_TOKEN"
    elif contains "$BUF" "_internal.config_tz"; then
        log "Got _internal.config_tz"
        miio_tz=$(echo "$BUF" | $JSHON -e params -e tz -u -Q)
        save_tz_conf "$miio_tz"
    elif contains "$BUF" "_internal.record_offline"; then
        log "Got _internal.record_offline_time"
        offline_time=$(echo "$BUF" | jshon -e params -e offline_time -u -Q)
        log "offline_time is $offline_time"
        offline_reason=$(echo "$BUF" | jshon -e params -e offline_reason -u -Q)
        log "offline_reason is $offline_reason"

        offline_ip=$(echo "$BUF" | jshon -e params -e offline_ip -u -Q)
        log "offline_ip is $offline_ip"

        offline_port=$(echo "$BUF" | jshon -e params -e offline_port -u -Q)
        log "offline_port is $offline_port"
        if [ $offline_time -eq 0 ]; then
            log "set offline_time to 0"
        fi
        #save by yourself
    else
        log "Unknown cmd: $BUF"
    fi
    done
}

sanity_check
send_helper_ready
main
