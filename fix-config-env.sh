#! /bin/bash

foundErrors=""

main() {
    if [ "$#" != 3 ]
    then
        echo "usage: ./${0} <namespace> <app> <name>"
        exit 1
    fi
    local namespace=$1
    local app=$2
    local name=$3
    envvars=$(getAllEnvVars $namespace $app $name)
    envpatch=$(echo "$envvars" | jq -s -c '.')
    kubectl -n $namespace get deploy $name -o json | jq --argjson envpatch "${envpatch}" '.spec.template.spec.containers[0].env=$envpatch' | kubectl -n $namespace replace -f -
}

getAllEnvVars() {
    local namespace=$1
    local app=$2
    local name=$3
    local appconfigname="${app}-dfwplatform-app-default-configs"
    globalscenv=$(getEnvVarsFromResource $namespace global secret secretKeyRef)
    echo "${globalscenv}"
    globalcmenv=$(getEnvVarsFromResource $namespace global cm configMapKeyRef)
    echo "${globalcmenv}"
    appcmenv=$(getEnvVarsFromResource $namespace $appconfigname cm configMapKeyRef)
    echo "${appcmenv}"
    appscenv=$(getEnvVarsFromResource $namespace $appconfigname secret secretKeyRef)
    echo "${appscenv}"
    brcmenv=$(getEnvVarsFromResource $namespace $name cm configMapKeyRef)
    echo "${brcmenv}"
    brscenv=$(getEnvVarsFromResource $namespace $name secret secretKeyRef)
    echo "${brscenv}"
    # Jaeger field path
    echo '{"name":"JAEGER_AGENT_HOST","valueFrom":{"fieldRef":{"apiVersion":"v1","fieldPath":"status.hostIP"}}}'
}

getEnvVarsFromResource() {
    local namespace=$1
    local name=$2
    local resType=$3
    local referenceType=$4

    local response=$(kubectl -n $namespace get $resType $name -o json --ignore-not-found)
    if [ -z "$response" ]
    then
        return
    fi
    local keys=$(echo "$response" | jq -r ".data|keys|.[]")
    for key in $keys
    do
        local envkey=$(echo "$response" | jq -r --arg datakey $key '.metadata.annotations[$datakey]')
        if [ -z "$envkey" ]
        then
            continue
        fi
        local envval=$(echo "$response" | jq -r --arg datakey $key '.data[$datakey]')
        printf "{\"name\": \"${envkey}\", \"valueFrom\":{\"${referenceType}\":{\"key\": \"${key}\", \"name\": \"${name}\"}}}"
    done
}



main "$@"
