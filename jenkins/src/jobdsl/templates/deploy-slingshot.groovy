job {

 	_snip ( 'scm', delegate )
    label('slingshot')

 	steps {

 		shell (
"""
export http_proxy=http://\${proxy}:80/
export https_proxy=\${http_proxy}
export no_proxy='.intuit.net, .intuit.com, 10.*.*.*, localhost, 127.0.0.1'

cd platform/scripts
rm -rf JSD-App.jar
branch=`echo \${full_branch} | sed 's#*/##g' | sed 's#[./]#-#g' | sed 's#release#rel#' | sed 's#hotfix#hot#' | sed 's#feature#feat#'`
wget -nv http://fmsscm.corp.intuit.net/fms-build/view/TAC/job/CI-devops-JSD-trunk/lastSuccessfulBuild/artifact/JSD-App/target/JSD-App.jar
bash -x ./deploy.sh -r \${region} -p \${profile} -P \${full_product} -b \${branch} -V \${build_version} -u \${artifact_url} -e \${env} create
"""
 		)

 		shell (
"""
export http_proxy=http://\${proxy}:80/
export https_proxy=\${http_proxy}
export no_proxy='.intuit.net, .intuit.com, 10.*.*.*, localhost, 127.0.0.1'

branch=`echo \${full_branch} | sed 's#*/##g' | sed 's#[./]#-#g' | sed 's#release#rel#' | sed 's#hotfix#hot#' | sed 's#feature#feat#'`
query () {
  BASE_URL=`./query_stack.py -r \${region} -p \${profile} -s "^dns-\${full_product}-\${env}\\\$" -o URL`
  URL=\${BASE_URL}/webapp/version
  curl --insecure  \${URL} || true
}

query1 () {
  BASE_URL=`./query_stack.py -r \${region} -p \${profile} -s "^dns-\${full_product}-\${env}\\\$" -o WebLoadBalancerDNSName`
  URL=https://\${BASE_URL}/webapp/version
  curl --insecure  \${URL} || true
}

set_delete_option () {
  source "../settings/\${env}.conf"

  if [ "\$delete_stack_all" == true ]; then
    DELETE_OPT="-c"
    if [ -n "\$delete_stack_history" ]; then
      DELETE_OPT="\$DELETE_OPT -l \$delete_stack_history"
    fi
    if [ -n "\$delete_stack_whitelist" ]; then
      DELETE_OPT="\$DELETE_OPT -w \$delete_stack_whitelist"
    fi
  else
    DELETE_OPT="-d"
  fi
}

cd platform/scripts
query1
rm -rf JSD-App.jar
wget -nv http://fmsscm.corp.intuit.net/fms-build/view/TAC/job/CI-devops-JSD-trunk/lastSuccessfulBuild/artifact/JSD-App/target/JSD-App.jar

set_delete_option
bash -x ./migrate.sh -p \${profile} -P \${full_product} -b \${branch} -V \${build_version} -r \${region} -e \${env} -z \${profile}.a.intuit.com \$DELETE_OPT

query1
"""
 		)
 	}
}
