#!/usr/bin/env bash
ROOT_DIR="$( cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )" && pwd )"
read -r -d '' USAGE <<EOF
cfdo.sh COMMAND CLUSTER ROLE
  COMMAND:
    create
    deploy
    delete
  CLUSTER
    CesiumDev
  ROLE:
    VPC
    Bastion
    DB
    WebServer
    Tunneler
    Builder
    ELB
EOF
TEMPLATES_DIR="$ROOT_DIR/templates"
PARAMETERS_FILE="$ROOT_DIR/parameters.yml"
LOOKUP_SCRIPT="$ROOT_DIR/bin/configlookup.py"
COMMAND="$1"
CLUSTER="$2"
TARGET="$3"
shift 3
VPC_ID="${CLUSTER}VPC"
STACK_NAME="${CLUSTER}${TARGET}"

function lookup {
    if [[ "$2" ]]; then
        echo $("$LOOKUP_SCRIPT" --default "$2" "$PARAMETERS_FILE" "$CLUSTER.$TARGET.$1")
    else
        echo $("$LOOKUP_SCRIPT" "$PARAMETERS_FILE" "$CLUSTER.$TARGET.$1")
    fi
}

case "$COMMAND" in
    create)
        case "$TARGET" in
            VPC)
                echo aws cloudformation create-stack \
                     --stack-name "$VPC_ID" \
                     --template-body "file://$TEMPLATES_DIR/vpc.cfn.yml" \
                     --parameters ParameterKey=ConfigTagParam,ParameterValue="$(lookup ConfigTagParam $CLUSTER)" \
                     ParameterKey=InstanceTenancy,ParameterValue="$(lookup InstanceTenancy dedicated)"
                ;;
            Bastion)
                aws cloudformation create-stack \
                    --stack-name "$STACK_NAME" \
                    --template-body "file://$TEMPLATES_DIR/bastion.cfn.yml" \
                    --parameters ParameterKey=NetworkStackName,ParameterValue="$VPC_ID" \
                    ParameterKey=KeyName,ParameterValue="$(lookup KeyName research-bastion)"
                ;;
            DB)
                echo "Enter database password:"
                read -s DB_PASSWORD
                aws cloudformation create-stack \
                    --stack-name "$STACK_NAME" \
                    --template-body "file://$TEMPLATES_DIR/db.cfn.yml" \
                    --parameters ParameterKey=NetworkStackName,ParameterValue="$VPC_ID" \
                    ParameterKey=DatabaseUser,ParameterValue=$(lookup DatabaseUser htcs) \
                    ParameterKey=DatabasePassword,ParameterValue="$DB_PASSWORD" \
                    ParameterKey=DatabaseName,ParameterValue=$(lookup DatabaseUser htcs) \
                    ParameterKey=EnvironmentName,ParameterValue=$(lookup EnvironmentName dev)
                ;;
            WebServer)
                aws cloudformation create-stack \
                    --stack-name "$STACK_NAME" \
                    --template-body "file://$TEMPLATES_DIR/webserver.cfn.yml" \
                    --parameters ParameterKey=NetworkStackName,ParameterValue="$VPC_ID" \
                    ParameterKey=KeyName,ParameterValue="$(lookup KeyName research-bastion)"
                ;;
            Tunneler)
                aws cloudformation create-stack \
                    --stack-name "$STACK_NAME" \
                    --template-body "file://$TEMPLATES_DIR/tunneler.cfn.yml" \
                    --parameters ParameterKey=NetworkStackName,ParameterValue="$VPC_ID" \
                    ParameterKey=KeyName,ParameterValue="$(lookup KeyName research-bastion)"
                ;;
            Builder)
                aws cloudformation create-stack \
                    --stack-name "$STACK_NAME" \
                    --template-body "file://$TEMPLATES_DIR/builder.cfn.yml" \
                    --parameters ParameterKey=NetworkStackName,ParameterValue="$VPC_ID" \
                    ParameterKey=KeyName,ParameterValue="$(lookup KeyName research-bastion)"
                ;;
            ELB)
                aws cloudformation create-stack \
                    --stack-name "$STACK_NAME" \
                    --template-body "file://$TEMPLATES_DIR/elb.cfn.yml" \
                    --parameters ParameterKey=NetworkStackName,ParameterValue="$VPC_ID"
                ;;
            *)
                echo "unrecognized deploy target: $TARGET" 2>&1
                exit 1
                ;;
        esac
        ;;
    deploy)
        case "$TARGET" in
            VPC)
                aws cloudformation deploy --stack-name "$VPC_ID" --template-file "$TEMPLATES_DIR/vpc.cfn.yml" $@
                ;;
            Bastion)
                aws cloudformation deploy --stack-name "$STACK_NAME" --template-file "$TEMPLATES_DIR/bastion.cfn.yml" $@
                ;;
            DB)
                aws cloudformation deploy --stack-name "$STACK_NAME" --template-file "$TEMPLATES_DIR/db.cfn.yml" $@
                ;;
            WebServer)
                aws cloudformation deploy --stack-name "$STACK_NAME" --template-file "$TEMPLATES_DIR/webserver.cfn.yml" $@
                ;;
            Tunneler)
                aws cloudformation deploy --stack-name "$STACK_NAME" --template-file "$TEMPLATES_DIR/tunneler.cfn.yml" $@
                ;;
            Builder)
                aws cloudformation deploy --stack-name "$STACK_NAME" --template-file "$TEMPLATES_DIR/builder.cfn.yml" $@
                ;;
            ELB)
                aws cloudformation deploy --stack-name "$STACK_NAME" --template-file "$TEMPLATES_DIR/elb.cfn.yml" $@
                ;;
            *)
                echo "unrecognized deploy target: $TARGET" 2>&1
                exit 1
                ;;
        esac
        ;;
    delete)
        aws cloudformation delete-stack --stack-name "$STACK_NAME"
        ;;
    *|--help|-h|help)
        echo "unrecognized command: $COMMAND" 2>&1
        echo "$USAGE"
        exit 1
        ;;
esac

