#!/bin/bash

components="
otc-bm-helper
otc-tiam
lms-api
otc-api
otc-ui
otc-webhook-manager
otc-bcdr-manager
continuous-delivery-broker
continuous-delivery-bss
cd-broker
git-cas
hosted-git-monitor
hosted-git-metrics
otc-git-broker
otc-github-helper
otc-cti-broker
otc-pagerduty-broker
otc-saucelabs-broker
otc-slack-broker
otc-toolchain-consumption
otc-status
otc-toolint-broker
otc-metrics-amplitude
otc-metrics-listener
otc-metrics-setup
otc-orion-consumption
otc-orion-broker
"

# The following vars are kown to be used within modules
excludeVars="
NEW_RELIC_APP_NAME
SECGRP
SLACK_BOT_NAME
SLACK_CHANNEL
SLACK_URL
log4js_logmet_component
log4js_logmet_enabled
log4js_logmet_logging_host
log4js_logmet_logging_port
log4js_logmet_space_id
log4js_syslog_appender_enabled
log4js_syslog_appender_host
log4js_syslog_appender_port
log4js_syslog_appender_product
log4js_syslog_appender_url
log4js_syslog_appender_whitelist
"

otc_bm_helper="otc-cf-broker"
git_cas="github-enterprise-cas"
hosted_git_monitor="github-enterprise-monitor"
otc_git_broker="otc-github-broker"

for component in $components 
do
  vars=$(cat /c/repositories/devops-config/environments/us-east/values.yaml | yq -y .[\"$component\"].env | awk -F ":" '{print $1};')
  echo "=== Examing component $component ==="
  for aVar in $vars
  do
    if [[ $excludeVars = *"$aVar"* ]]; then
	  doing=something
      #echo "It's excluded!"
	else
      normalizedVar=${aVar//__/:}
	  normalized_repo="${component//-/_}"
	  repoToInspect=${!normalized_repo:-"${component}"}
      grep -q -l -c -r --include=*.js --include=*.py --include=*.java --include=*.yml --exclude-dir=*test* -e "$normalizedVar" -e \'$normalizedVar\' -e \"$normalizedVar\" /c/repositories/$repoToInspect
      if [ "$?" == "1" ]; then
	    # If there is some : in the env var, we should look for env var named without last token 
        # No match found - candidate to remove
        echo "$normalizedVar - no reference found using grep \"$normalizedVar\" or grep '$normalizedVar' produces no result: candidate to deletion"
      fi
    fi
    #echo "==================================="
  done
  echo "===================================="
done
