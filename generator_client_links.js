const fs = require('fs');

/**
 * 格式化nginx配置
 * @returns {string[]}
 */
const formatNginx = (nginxPath) => {
    let nginxConfig = fs.readFileSync(nginxPath).toString().split('listen');
    nginxConfig = nginxConfig.map(v => {
        return v.replace(/(^\s*)/g, '');
    }).filter(v => {
        if (v.substring(0, 3) === '443') {
            return true;
        }
    });
    nginxConfig = nginxConfig.map(v => {
        v = v.split('\n').map(v => {
            return v.replace(/(^\s*)/g, '')
                .replace(/[\;/=]/g, '')
                .replace(/[\{/=]/g, '')
                .replace(/[\}/=]/g, '')
                .replace(/(\s*$)/g, '');
        }).filter(v => v.includes('server_name') || v.includes('location')).map(v => {
            v = v.split(' ');
            if (v[1]) {
                return v[1];
            }
        }).filter(v => v);
        return v;
    });
    return nginxConfig;
};
/**
 * 格式化v2ray配置文件
 */
const formatV2rayConfig = (v2RayPath) => {
    let nginxConfig = fs.readFileSync(v2RayPath).toString();
    nginxConfig = JSON.parse(nginxConfig).inbounds;
    nginxConfig = nginxConfig.map(v => {
        return {
            users: v.settings.clients,
            security: v.streamSettings.security,
            network: v.streamSettings.network,
            path: v.streamSettings.wsSettings.path,
        };
    });
    return nginxConfig;
};
const formatResult = () => {
    let v2RayPath = null;
    let nginxPath = null;
    if (process && process.argv.length === 4) {
        v2RayPath = process.argv[2];
        nginxPath = process.argv[3];
    }
    if (!v2RayPath || !nginxPath) {
        console.log('message 参数错误');
        return;
    }

    let v2rayResult = formatV2rayConfig(v2RayPath);
    let nginxResult = formatNginx(nginxPath);
    let configArr = [];

    v2rayResult.forEach(v => {
        let item = nginxResult.filter(v2 => {
            return v2.includes(v.path.replace(/[//=]/g, ''));
        });
        item.forEach(v2 => {

            v.users.forEach(v3 => {
                configArr.push({
                    port: v.network === 'ws' ? 443 : 0,
                    tls: v.network === 'ws' ? 'tls' : false,
                    host: '',
                    type: 'none',
                    path: v.path,
                    net: v.network,
                    add: v2[0],
                    ps: v3.email,
                    aid: v3.level,
                    v: v3.v,
                    id: v3.id,
                });
            });
        });
    });
    // configArr.push(configArr[0]);
    configArr = configArr.map(v => {
        return `vmess://${Buffer.from(JSON.stringify(v)).toString('base64')}`;
    });
    console.log(configArr.toString().replace(/,/g,' '));
};
formatResult();
