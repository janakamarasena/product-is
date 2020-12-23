#!/bin/bash +x
REPOSITORY=product-is
GIT_USERNAME=janama360
PRODUCT_REPOSITORY_FORKED=${GIT_USERNAME}/${REPOSITORY}

PRODUCT_REPOSITORY_PUBLIC=wso2/${REPOSITORY}
REMOTE_PRODUCT_REPOSITORY_PUBLIC=wso2-is-public
DEPENDENCY_UPGRADE_BRANCH_NAME_PREFIX=dev_IS_dependency_updater
DEPENDENCY_UPGRADE_BRANCH_NAME_TIMESTAMP=$(date +%s%3N)
DEPENDENCY_UPGRADE_BRANCH_NAME=${DEPENDENCY_UPGRADE_BRANCH_NAME_PREFIX}'/'${DEPENDENCY_UPGRADE_BRANCH_NAME_TIMESTAMP}
export MAVEN_OPTS=-Dfile.encoding=utf-8
BUILD_STATUS = FAILURE
UPDATES_STATUS = 'Possibly a new dependency update failed the build'


echo ""
echo "Starting dependency upgrade"
echo "=========================================================="


echo ""
echo "Cloning: https://github.com/'${PRODUCT_REPOSITORY_FORKED}"
echo "=========================================================="
git clone 'https://github.com/'${PRODUCT_REPOSITORY_FORKED}'.git'
cd ${REPOSITORY}

echo ""
echo 'Add remote: '${REMOTE_PRODUCT_REPOSITORY_PUBLIC} 'as https://github.com/'${PRODUCT_REPOSITORY_PUBLIC}
echo "=========================================================="
git remote add ${REMOTE_PRODUCT_REPOSITORY_PUBLIC} 'https://@github.com/'${PRODUCT_REPOSITORY_PUBLIC}

echo ""
echo 'Fetching:' ${REMOTE_PRODUCT_REPOSITORY_PUBLIC}
echo "=========================================================="
git fetch ${REMOTE_PRODUCT_REPOSITORY_PUBLIC}

echo ""
echo 'Checking out:' ${REMOTE_PRODUCT_REPOSITORY_PUBLIC} 'master branch'
echo "=========================================================="
git checkout -b ${DEPENDENCY_UPGRADE_BRANCH_NAME} ${REMOTE_PRODUCT_REPOSITORY_PUBLIC}'/master'

echo ""
echo 'Updating dependencies'
echo "=========================================================="
mvn versions:update-properties -U -DgenerateBackupPoms=false -Dincludes=\
org.wso2.carbon.identity.*,\
org.wso2.carbon.extension.identity.*,\
org.wso2.identity.*,\
org.wso2.carbon.consent.*,\
org.wso2.carbon.utils,\
org.wso2.charon,\
org.apache.rampart.wso2,\
org.apache.ws.security.wso2 --batch-mode

echo ""
echo 'Check if new updates are available'
echo "=========================================================="

echo ""
echo 'Available updates'
echo "=========================================================="
git diff --color > dependency_updates.diff
cat dependency_updates.diff

echo ""
echo 'Committing dependency updates'
echo "=========================================================="
git config --global user.name ${GIT_USERNAME}
git commit -a -m 'Bump dependencies from '${DEPENDENCY_UPGRADE_BRANCH_NAME}


echo ""
echo "Local dependency update is completed and successfully prepared for build"
echo "=========================================================="


mvn clean install -Dmaven.test.skip=true --batch-mode | tee mvn-build.log
#mvn clean install -Dmaven.test.failure.ignore=false


REPOSITORY=product-is
REMOTE_PRODUCT_REPOSITORY_PUBLIC=wso2-is-public
PRODUCT_REPOSITORY_FORKED=${GIT_USERNAME}/${REPOSITORY}
PRODUCT_REPOSITORY_PUBLIC=wso2/${REPOSITORY}
BUILD_STATUS = SUCCESS
UPDATES_STATUS = 'There are no new updates'


if [ -s dependency_updates.diff ]
then
  UPDATES_STATUS = 'There are new updates available'
  echo ""
  echo "Dependency updates are available"
  echo "=========================================================="
  
  echo ""
  echo 'Preparing to push changes to https://github.com/'${PRODUCT_REPOSITORY_FORKED}
  echo "=========================================================="
  DEPENDENCY_UPGRADE_BRANCH_NAME=$(git branch | grep -oP "^\*\s+\K\S+$")
  
  echo ""
  echo 'Configuring the origin as: https://github.com/'${PRODUCT_REPOSITORY_FORKED}
  echo "=========================================================="
  git remote rm origin
  git remote add origin 'https://'${GIT_TOKEN}'@github.com/'${PRODUCT_REPOSITORY_FORKED}
  
  
  echo ""
  echo 'Pushing the branch: '${DEPENDENCY_UPGRADE_BRANCH_NAME} 'to the origin'
  echo "=========================================================="
  git push -u origin ${DEPENDENCY_UPGRADE_BRANCH_NAME}
  
  echo ""
  echo 'Creating the pull request with upgraded dependencies to the https://github.com/'${PRODUCT_REPOSITORY_PUBLIC}
  echo "=========================================================="
  TITLE="Bump Dependencies #"$BUILD_NUMBER
  STATUS=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" -k -X \
  POST https://api.github.com/repos/${PRODUCT_REPOSITORY_PUBLIC}/pulls \
  -H "Authorization: token "${GIT_TOKEN}"" \
  -H "Content-Type: application/json" \
  -d '{ "title": "'"${TITLE}"'","body": "Bumps dependencies for product-is.","head": "'"${GIT_USERNAME}:${DEPENDENCY_UPGRADE_BRANCH_NAME}"'","base":"master"}')
  
  # extract the body
  HTTP_BODY=$(echo $STATUS | sed -e 's/HTTPSTATUS\:.*//g')
  
  # extract the status
  HTTP_STATUS=$(echo $STATUS | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
  
  if [ $HTTP_STATUS -eq 201 ]; then
  	UPDATES_STATUS = 'There are new updates available. A pull request available in: https://github.com/wso2/product-is/pulls'
    echo 'Pull request made successfully'
    echo "=========================================================="
    echo "HTTP STATUS: "$HTTP_STATUS
    echo "HTTP Response: "$HTTP_BODY
    echo ""
    exit 0
  else
    echo 'Pull request was unsuccessful'
    echo "=========================================================="
    echo "HTTP STATUS: "$HTTP_STATUS
    echo "HTTP Response: "$HTTP_BODY
    echo ""
    exit 1
  fi
else
  echo ""
  echo "There are no dependency updates available"
  echo "=========================================================="
  exit 0
fi
