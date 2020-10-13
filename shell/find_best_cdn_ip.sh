echoContent skyBlue "\n进度 $1/${totalProgress} : 修改CDN节点"
    if [[ -d "/etc/v2ray-agent" ]] && [[ -d "/etc/v2ray-agent/v2ray" ]]
    then
        local configPath=
        if [[ -f "/etc/v2ray-agent/v2ray/config.json" ]]
        then
            configPath="${configPath}"
        elif [[ -d "/etc/v2ray-agent/v2ray/conf" ]] && [[ -f "/etc/v2ray-agent/v2ray/conf/VLESS_TCP_inbounds.json" ]]
        then
            configPath="/etc/v2ray-agent/v2ray/conf/VLESS_TCP_inbounds.json"
        else
            echoContent red " ---> 未安装"
            exit 0;
        fi
        local add=`cat ${configPath}|grep -v grep|grep add`
        if [[ ! -z ${add} ]]
        then
            echoContent red "=============================================================="
            echoContent yellow "1.CNAME www.digitalocean.com"
            echoContent yellow "2.CNAME amp.cloudflare.com"
            echoContent yellow "3.CNAME domain08.qiu4.ml"
            echoContent yellow "4.手动输入"
            echoContent red "=============================================================="
            read -p "请选择:" selectCDNType
            case ${selectCDNType} in
            1)
                setDomain="www.digitalocean.com"
            ;;
            2)
                setDomain="amp.cloudflare.com"
            ;;
            3)
                setDomain="domain08.qiu4.ml"
            ;;
            4)
                read -p "请输入想要自定义CDN IP或者域名:" setDomain
            ;;
            esac
            if [[ ! -z ${setDomain} ]]
            then
                # v2ray
                add=`echo ${add}|awk -F '["]' '{print $4}'`
                if [[ ! -z ${add} ]]
                then
                    sed -i "s/${add}/${setDomain}/g"  `grep "${add}" -rl ${configPath}`
                fi
                # sed -i "s/domain08.qiu4.ml1/domain08.qiu4.ml/g"  `grep "domain08.qiu4.ml1" -rl ${configPath}`
                if [[ `cat ${configPath}|grep -v grep|grep add|awk -F '["]' '{print $4}'` = ${setDomain} ]]
                then
                    echoContent green " ---> V2Ray CDN修改成功"
                    handleV2Ray stop
                    handleV2Ray start
                else
                    echoContent red " ---> 修改V2Ray CDN失败"
                fi

                # trojan
                if [[ -d "/etc/v2ray-agent/trojan" ]] && [[ -f "/etc/v2ray-agent/trojan/config.json" ]]
                then
                    add=`cat /etc/v2ray-agent/trojan/config.json|jq .websocket.add|awk -F '["]' '{print $2}'`
                    if [[ ! -z ${add} ]]
                    then
                        sed -i "s/${add}/${setDomain}/g"  `grep "${add}" -rl /etc/v2ray-agent/trojan/config.json`
                    fi
                fi

                if [[ `cat /etc/v2ray-agent/trojan/config.json|jq .websocket.add|awk -F '["]' '{print $2}'` = ${setDomain} ]]
                then
                    echoContent green "\n ---> Trojan CDN修改成功"
                    handleTrojanGo stop
                    handleTrojanGo start
                else
                    echoContent red " ---> 修改Trojan CDN失败"
                fi
            fi
        else
            echoContent red " ---> 未安装可用类型"
        fi
    else
        echoContent red " ---> 未安装"
    fi
    menu