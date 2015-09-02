job {

 	_snip ( 'scm', delegate )
  label('slingshot')

 	steps {
     shell (
"""
#!/bin/bash
export PATH=\$PATH:/usr/java/default/bin:\$(pwd)/platform/scripts
target_bucket_name=iss-\${profile}-secrets-\${region}

if [[ -n "\$proxy" ]]
then
    export http_proxy=http://\$proxy:80/
    export https_proxy=\$http_proxy
    export no_proxy='.intuit.net, .intuit.com, 10.*.*.*, localhost, 127.0.0.1'
fi
#
# configure cert-engine
#
echo "
ORG_UNIT=SBG
ORG=\\"INTUIT INC.\\"
CITY=\\"San Diego\\"
STATE=California
COUNTRY=US
venafi_folder[1]=\\"\\VED\\Policy\\SBG\\AWS\\VeriSign-ST\\"
venafi_ca_template[1]=\\"\\VED\\Policy\\_CA Templates\\VeriSign Standard CA SHA-2\\"
venafi_folder[2]=\\"\\VED\\Policy\\SBG\\AWS\\VeriSign-EV\\"
venafi_ca_template[2]=\\"\\VED\\Policy\\_CA Templates\\VeriSign EV CA SHA-2\\"
" > \$HOME/.cert-engine-ca-defs
cat \$HOME/.cert-engine-ca-defs
tag1="U2FsdGVkX19F4CrZK2jRxF/8ucWVKkRZDE5uwKWJux/vXW2MWjr8f/CGSqaa+/iD\nkoFcelpl7dD5d7R3T8S8v6Obh8z2QVNUZGXUprChETQ="
tag2="b3BlbnNzbCBhZXMtMjU2LWVjYiAgLWQgLWsgMTIzNDU2IC1hID4gJEhPTUUvLmF1dGguanNvbgo="
tag3="base64 -d"
#
# form CN
#
base_domain=a.intuit.com

if [[ "\$profile" =~ "-prd" || "\$profile" =~ "-prod" ]]
then
    environments=\$env
    envtype=prd
    branches=\$(git branch -a | awk 'BEGIN {FS="/"} /remotes/ {print \$NF}' | awk '/^master\$/||/^develop\$/||/^feat-/||/^rel-/||/^hot-/ {print}')
    CN="\$env-master-\${full_product}-\$envtype.\$base_domain"
else
    environments=\$(grep ^environments= platform/settings/aws-preprod.conf | cut -d= -f2 | tr "," " ")
    envtype=ppd
    branches=\$(git branch -a | awk 'BEGIN {FS="/"} /remotes/ {print \$NF}')
    CN="e2e-master-\${full_product}-\$envtype.\$base_domain"
fi

for environment in \$environments
do
    for branch in \$branches
    do
	anotherSAN="\$environment-\$branch-\$full_product-\$envtype.\$base_domain"
	if [[ "\$CN" != "\$anotherSAN" ]]
	then
	    if [[ -z "\$SAN" ]]
	    then
		SAN="\$anotherSAN"
	    else
		SAN="\$SAN,\$anotherSAN"
	    fi
	fi
    done
done

echo "CN:  \$CN"
echo "SAN: \$SAN"

# set certtype; 1 - standard, 2 - EV
if [[ "\$EV_certificate" = "false" || -z "\$EV_certificate" ]]; then certtype=1; else certtype=2; fi
# set SAN option
if [[ -n "\$SAN" ]]; then sanopt="-A \$SAN"; else sanopt=""; fi
# set renewal option; -f will force renewal
if [[ "\$Force_Renewal" = "true"   ]]; then renewopt="-f"; else renewopt=""; fi
#
# action starts here
#
if [ \$(aws --profile \$profile s3 ls s3://\$target_bucket_name/ >/dev/null 2>&1; echo \$?) -ne 0 ]; then
    echo "[ERROR] no target bucket: \$target_bucket_name"
    exit 1
fi

echo -e "\$tag1" | eval \$(echo \$tag2|\$tag3)

temp_folder=\$(mktemp -d /dev/shm/secrets_XXXXXXXXXXX)
cert-engine -S "\$CN" -t \$certtype -w \$full_product -n \$sanopt \$renewopt -o \$temp_folder
if [[ \$? -ne 0 ]]
then
    echo "ERROR: certificate retrieval failed"
    exit 1
fi
ls -l \$temp_folder

cd platform/scripts
for environment in \$environments
do
    for file in \$temp_folder/*
    do
	filename=\$(basename \$file)
	./secrets-wrapper.sh -b \$target_bucket_name -r \$region -p \$profile -P "\$full_product/\$environment/web" -n \$filename -f \$file put
	./secrets-wrapper.sh -b \$target_bucket_name -r \$region -p \$profile -P "\$full_product/\$environment/app" -n \$filename -f \$file put
    done
done

rm -rf \$temp_folder
"""
     )
  }
}
