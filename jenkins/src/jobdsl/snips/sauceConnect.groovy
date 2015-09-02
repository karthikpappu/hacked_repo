def c = {
        if ( (this.binding.hasVariable("enableSauceConnect")) && Boolean.valueOf(enableSauceConnect) ) {
         configure { node ->
              node / buildWrappers << 'hudson.plugins.sauce__ondemand.SauceOnDemandBuildWrapper' ( plugin: "sauce-ondemand@1.129" ) {
              startingURL('')
              sauceConnectPath('')
              useOldSauceConnect(false)
              enableSauceConnect(true)
              seleniumHost('')
              seleniumPort('')
                'credentials'{
                  username("${sauce_username}")
                  apiKey("${sauce_access_api_key}")
                }
                'seleniumInformation' {
                  seleniumBrowsers()
                  webDriverBrowsers()
                  isWebDriver(true)
                  isAppium(false)
                }
             webDriverBrowsers(reference: "../seleniumInformation/webDriverBrowsers")
             useLatestVersion(false)
             launchSauceConnectOnSlave(false)
             httpsProtocol()
             options()
             verboseLogging(false)
             condition(class: "org.jenkins_ci.plugins.run_condition.core.AlwaysRun", plugin: "run-condition@1.0")
            }
        }
      }
}
