#!/bin/bash

NODE_POOL=""
SOLR_REPLICAS=3
RELEASE=f5
CLUSTER_NAME=
PROMETHEUS_ON=true
SOLR_DISK_GB=50
PROVIDER=gke

function print_usage() {
  CMD="$1"
  ERROR_MSG="$2"

  if [ "$ERROR_MSG" != "" ]; then
    echo -e "\nERROR: $ERROR_MSG"
  fi

  echo -e "\nUse this script to create a custom Fusion values yaml from a template"
  echo -e "\nUsage: $CMD <yaml-file-to-create> [OPTIONS] ... where OPTIONS include:\n"
  echo -e "  -c               Cluster name (required)\n"
  echo -e "  -r               Helm release name for installing Fusion 5, defaults to 'f5'\n"
  echo -e "  --provider       Name of your K8s provider, e.g. eks, aks, gke; defaults to 'gke'\n"
  echo -e "  --prometheus     Enable Prometheus? true or false, defaults to true\n"
  echo -e "  --num-solr       Number of Solr pods to deploy, defaults to 3\n"
  echo -e "  --solr-disk-gb   Size (in gigabytes) of the Solr persistent volume claim, defaults to 50\n"
  echo -e "  --node-pool      Node pool label to assign pods to specific nodes, this option is only useful for existing clusters where you defined a custom node pool;\n                    defaults to '${NODE_POOL}', wrap the arg in double-quotes\n"
}

SCRIPT_CMD="$0"
MY_VALUES="$1"

if [ "$MY_VALUES" == "" ]; then
  print_usage "$SCRIPT_CMD" "Please provide the name of the values yaml file to create as the first arg to this script!"
  exit 1
fi

# start parsing
shift 1

if [ $# -gt 1 ]; then
  while true; do
    case "$1" in
        -c)
            if [[ -z "$2" || "${2:0:1}" == "-" ]]; then
              print_usage "$SCRIPT_CMD" "Missing value for the -c parameter!"
              exit 1
            fi
            CLUSTER_NAME="$2"
            shift 2
        ;;
        -r)
            if [[ -z "$2" || "${2:0:1}" == "-" ]]; then
              print_usage "$SCRIPT_CMD" "Missing value for the -r parameter!"
              exit 1
            fi
            RELEASE="$2"
            shift 2
        ;;
        --provider)
            if [[ -z "$2" || "${2:0:1}" == "-" ]]; then
              print_usage "$SCRIPT_CMD" "Missing value for the --provider parameter!"
              exit 1
            fi
            PROVIDER="$2"
            shift 2
        ;;
        --prometheus)
            if [[ -z "$2" || "${2:0:1}" == "-" ]]; then
              print_usage "$SCRIPT_CMD" "Missing value for the --prometheus parameter!"
              exit 1
            fi
            PROMETHEUS_ON="$2"
            shift 2
        ;;
        --num-solr)
            if [[ -z "$2" || "${2:0:1}" == "-" ]]; then
              print_usage "$SCRIPT_CMD" "Missing value for the --num-solr parameter!"
              exit 1
            fi
            SOLR_REPLICAS=$2
            shift 2
        ;;
        --solr-disk-gb)
            if [[ -z "$2" || "${2:0:1}" == "-" ]]; then
              print_usage "$SCRIPT_CMD" "Missing value for the --solr-disk-gb parameter!"
              exit 1
            fi
            SOLR_DISK_GB=$2
            shift 2
        ;;
        --node-pool)
            if [[ -z "$2" || "${2:0:1}" == "-" ]]; then
              print_usage "$SCRIPT_CMD" "Missing value for the --node-pool parameter!"
              exit 1
            fi
            NODE_POOL="$2"
            shift 2
        ;;
        -help|-usage|--help|--usage)
            print_usage "$SCRIPT_CMD"
            exit 0
        ;;
        --)
            shift
            break
        ;;
        *)
            if [ "$1" != "" ]; then
              print_usage "$SCRIPT_CMD" "Unrecognized or misplaced argument: $1!"
              exit 1
            else
              break # out-of-args, stop looping
            fi
        ;;
    esac
  done
fi

if [ "$CLUSTER_NAME" == "" ]; then
  print_usage "$SCRIPT_CMD" "Please provide the K8s cluster name using: -c <cluster>"
  exit 1
fi

if [ "${NODE_POOL}" == "" ]; then
  if [ "${PROVIDER}" == "eks" ]; then
    NODE_POOL="alpha.eksctl.io/nodegroup-name: standard-workers"
  elif [ "${PROVIDER}" == "gke" ]; then
    NODE_POOL="cloud.google.com/gke-nodepool: default-pool"
  else
    NODE_POOL="{}"
  fi
fi

cp customize_fusion_values.yaml.example $MY_VALUES
if [[ "$OSTYPE" == "linux-gnu" ]]; then
  sed -i -e "s|{NODE_POOL}|${NODE_POOL}|g" "$MY_VALUES"
  sed -i -e "s|{SOLR_REPLICAS}|${SOLR_REPLICAS}|g" "$MY_VALUES"
  sed -i -e "s|{RELEASE}|${RELEASE}|g" "$MY_VALUES"
  sed -i -e "s|{PROMETHEUS}|${PROMETHEUS_ON}|g" "$MY_VALUES"
  sed -i -e "s|{SOLR_DISK_GB}|${SOLR_DISK_GB}|g" "$MY_VALUES"
else
  sed -i '' -e "s|{NODE_POOL}|${NODE_POOL}|g" "$MY_VALUES"
  sed -i '' -e "s|{SOLR_REPLICAS}|${SOLR_REPLICAS}|g" "$MY_VALUES"
  sed -i '' -e "s|{RELEASE}|${RELEASE}|g" "$MY_VALUES"
  sed -i '' -e "s|{PROMETHEUS}|${PROMETHEUS_ON}|g" "$MY_VALUES"
  sed -i '' -e "s|{SOLR_DISK_GB}|${SOLR_DISK_GB}|g" "$MY_VALUES"
fi
echo -e "\nCreated Fusion custom values yaml: ${MY_VALUES}\n"

if [ "$PROMETHEUS_ON" == "true" ]; then
  MONITORING_VALUES="${PROVIDER}_${CLUSTER_NAME}_${RELEASE}_monitoring_values.yaml"
  if [ ! -f "${MONITORING_VALUES}" ]; then
    cp example-values/monitoring-values.yaml "${MONITORING_VALUES}"
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
      sed -i -e "s|{NODE_POOL}|${NODE_POOL}|g" "${MONITORING_VALUES}"
      sed -i -e "s|{NAMESPACE}|${NAMESPACE}|g" "${MONITORING_VALUES}"
    else
      sed -i '' -e "s|{NODE_POOL}|${NODE_POOL}|g" "${MONITORING_VALUES}"
      sed -i '' -e "s|{NAMESPACE}|${NAMESPACE}|g" "${MONITORING_VALUES}"
    fi
    echo -e "\nCreated Monitoring custom values yaml: ${MONITORING_VALUES}. Keep this file handy as you'll need it to customize your Monitoring installation.\n"
  fi
fi
