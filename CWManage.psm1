#region [Helpers]-------
    function Connect-CWM {
        <#
            .SYNOPSIS
            This will initialize the authorization variable.
                
            .DESCRIPTION
            This will create a global variable that contains all needed connection and authorization information.
            All other commands from the module will call this variable to get connection information.
                
            .PARAMETER Server
            The URL of your ConnectWise Mange server.
            Example: manage.mydomain.com
                
            .PARAMETER Company
            The login company.
                                                
            .PARAMETER pubkey
            Public API key created by a user
            docs: My Account
                
            .PARAMETER privatekey
            Private API key created by a user
            docs: My Account

            .PARAMETER Credentials
            Manage username and password as a PSCredential object [pscredential].

            .PARAMETER IntegratorUser
            The integrator username
            docs: Member Impersonation
                
            .PARAMETER IntegratorPass
            The integrator password
            docs: Member Impersonation

            .PARAMETER MemberID
            The member that you are impersonating

            .PARAMETER Force
            Ignore cached information and recreate

            .PARAMETER DontWarn
            Used to suppress the warning about integrator accounts.
                
            .EXAMPLE
            $Connection = @{
                Server = $Server
                Company = $Company 
                pubkey = $pubkey
                privatekey = $privatekey
            }
            Connect-CWM @Connection

            .EXAMPLE
            $Connection = @{
                Server = $Server
                Company = $Company 
                IntegratorUser = $IntegratorUser
                IntegratorPass = $IntegratorPass
            }
            Connect-CWM @Connection

            .EXAMPLE
            $Connection = @{
                Server = $Server
                Company = $Company 
                IntegratorUser = $IntegratorUser
                IntegratorPass = $IntegratorPass
                MemberID = $MemberID
            }
            Connect-CWM @Connection
            
            .EXAMPLE
            $Connection = @{
                Server = $Server
                Company = $Company 
                Credentials = $Credentials
            }
            Connect-CWM @Connection
                
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018

            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/Manage/Developer_Guide#Authentication
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [string]$Server,
            [Parameter(Mandatory=$true)]
            [string]$Company,
            [string]$pubkey,
            [string]$privatekey,
            [pscredential]$Credentials,
            [string]$IntegratorUser,
            [string]$IntegratorPass,
            [string]$MemberID,
            [switch]$Force,
            [switch]$DontWarn
        )

        # Version supported
        $Version = '3.0.0'

        if ((($global:CWMServerConnection -and !$global:CWMServerConnection.expiration) -or $global:CWMServerConnection.expiration -gt $(Get-Date)) -and !$Force) {
            Write-Verbose "Using cached Authentication information."
            return
        }

        # API key
        if($pubkey -and $privatekey){
            Write-Verbose "Using API Key authentication"
            $Authstring  = "$($Company)+$($pubkey):$($privatekey)"
            $encodedAuth  = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($Authstring));
            $Headers = @{
                Authorization = "Basic $encodedAuth"
                'Cache-Control'= 'no-cache'
            }
        }

        # Cookies, yumy
        elseif($Credentials){
            Write-Verbose "Using Cookie authentication"
            $global:CWMServerConnection = @{}
            $Headers = @{}
            $Body = @{
                CompanyName = $Company
                UserName = $Credentials.UserName
                Password = $Credentials.GetNetworkCredential().Password
            }
            $URI = 'https://service.itnow.net/v4_6_release//login/login.aspx?response=json'
            $WebRequestArguments = @{
                Uri = $Uri
                Method = 'Post'
                Body = $Body
                SessionVariable = 'global:CWMSession'
            }
            # Create session variable. Cookies are stored in that object
            $null = Invoke-CWMWebRequest -Arguments $WebRequestArguments
        }

        # Integrator account w/ w/o member id
        elseif($IntegratorUser -and $IntegratorPass){
            Write-Verbose "Using Integrator authentication"
            if(!$DontWarn){
                Write-Warning "Please move to a different authentication method."
                Write-Warning "Use the -DontWarn switch to suppress this message."
                Write-Warning "https://developer.connectwise.com/Products/Manage/Developer_Guide#Authentication"
            }
            
            $Authstring  = $Company + '+' + $IntegratorUser + ':' + $IntegratorPass
            $encodedAuth  = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($Authstring))
            $Headers = @{
                Authorization = "Basic $encodedAuth"
                'x-CW-usertype' = "integrator"
                'Cache-Control'= 'no-cache'
            }

            if ($MemberID) {
                Write-Verbose "Impersonating user, $MemberID"        
                $URL = "https://$($Server)/v4_6_release/apis/3.0/system/members/$($MemberID)/tokens"
                $Body = @{
                    memberIdentifier = $MemberID
                }
                
                $global:CWMServerConnection = @{
                    Server = $Server
                    Headers = $Headers
                    Session = $CWMSession
                }            
                $WebRequestArguments = @{
                    Method = 'Post'
                    Uri = $URL
                    Body = $Body
                    ContentType = 'application/json'
                }
                $Result = Invoke-CWMWebRequest -Arguments $WebRequestArguments
                if($Result.content){
                    $Result = $Result.content | ConvertFrom-Json
                }
                else {
                    Write-Error "Issue getting Auth Token for Impersonated user, $MemberID"
                    return
                }

                # Create auth header for Impersonated user
                $expiration = [datetime]$Result.expiration
                $Authstring  = $Company + '+' + $Result.publicKey + ':' + $Result.privateKey
                $encodedAuth  = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(($Authstring)));
                $Headers = @{
                    Authorization = "Basic $encodedAuth"
                    'Cache-Control'= 'no-cache'
                }    
            }
        }
            
        # not enough info
        else {
            Write-Error "Valid authentication parameters not passed"
            return
        }

        # Create the Server Connection object    
        $global:CWMServerConnection = @{
            Server = $Server
            Headers = $Headers
            Session = $CWMSession
            expiration = $expiration
        }

        # Set version header info
        $global:CWMServerConnection.Headers.Accept = "application/vnd.connectwise.com+json; version=$Version"

        # Validate connection info
        Write-Verbose 'Validating authentication'
        $Info = Get-CWMSystemInfo
        if(!$Info) {
            Write-Host -BackgroundColor Black -ForegroundColor Red "Connection has been halted."
            Disconnect-CWM
            return
        }

        $global:CWMServerConnection.Version = $Info.version
        Write-Verbose 'Connection successful.'
        Write-Verbose '$CWMServerConnection, variable initialized.'
    }
    function Disconnect-CWM {
        <#
            .SYNOPSIS
            This will remove the ConnectWise Manage authorization variable.
                              
            .EXAMPLE
            Disconnect-CWM 
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018

            .LINK
            http://labtechconsulting.com
        #>
        [CmdletBinding()]
        param()
        $null = Remove-Variable -Name CWMServerConnection -Scope global -Force -Confirm:$false -ErrorAction SilentlyContinue
        if($CWMServerConnection -or $global:CWMServerConnection) {
            Write-Error "There was an error clearing connection information.`n$($Error[0])"
        } else {
            Write-Verbose '$CWMServerConnection, variable removed.'
        }
    }
    function ConvertTo-CWMTime {
        <#
            .SYNOPSIS
            Converts [datetime] to the time format used in condition queries.
            
            .DESCRIPTION
            This will convert an input to a universal date time object then output in a format used by the ConnectWise Manage API.
            
            .PARAMETER Date
            Date used in conversion.
            
            .EXAMPLE
            ConvertTo-CWMTime $(Get-Date).AddDays(1)
            Will output tomorrows date.
            
            .NOTES
            Author: Chris Taylor
            Date: 10/16/2018

            .LINK
            http://labtechconsulting.com
        #>
        param(
        [datetime]$Date
        )
        return "[$(Get-Date $Date.ToUniversalTime() -format yyyy-MM-ddTHH:mm:ssZ)]"
    }
    function ConvertFrom-CWMTime {
        <#
        .SYNOPSIS
        Converts ConnectWise Manage datetime string to a [datetime] object.
            
        .DESCRIPTION
        This will convert an input string to [datetime] object.
            
        .PARAMETER Date
        Date used in conversion.
    
        .OUTPUT
        [datetime]
            
        .EXAMPLE
        ConvertFrom-CWMTime -Date '[2018-10-20T00:14:56Z]'
        Will return a [datetime] conversion of datetime string.
            
        .NOTES
        Author: Chris Taylor
        Date: 10/16/2018
    
        .LINK
        http://labtechconsulting.com
        #>
        param(
        [string]$Date
        )
        return Get-Date $Date.Trim('[',']')
    }
    function ConvertFrom-CWMColumnRow {
        <#
            .SYNOPSIS
            Take Column Row output from Manage and converts it to an object
        
            .PARAMETER Data
            Column row object to be converted
            
            .EXAMPLE
            ConvertFrom-CWMColumnRow -Data $Data
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
        #>
        param(
            $Data
        )
        # Clean the returned object up
        $Item = @{}
        For ($a=0; $a -lt $Data.row_values.count; $a++){
            $Property = @()
            For ($b=0; $b -lt $Data.column_definitions.count; $b++){
                $Property += @{$(($Data.column_definitions[$b] | Get-Member -MemberType NoteProperty).Name) = $($Data.row_values[$a][$b])}
            }
            $Item.add($Property.Description,[PSCustomObject]$Property)
        }
        return [PSCustomObject]$Item
    }
    function Invoke-CWMGetMaster {
        <#
            .SYNOPSIS
            This will be basis of all get calls to the ConnectWise Manage API.
                
            .DESCRIPTION
            This will insure that all GET requests are handled correctly.
                
            .PARAMETER Arguments
            A hash table of parameters

            .PARAMETER URI
            The URI of the GET endpoint
                                
            .EXAMPLE
            Invoke-CWMGetMaster -Arguments $Arguments -URI $URI
                
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018

            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/Manage/Developer_Guide#Authentication
        #>
        [CmdletBinding()]
        param (
            $Arguments,
            [string]$URI
        )
        
        if ($Arguments.Condition) {
            $Condition = [System.Web.HttpUtility]::UrlEncode($Arguments.Condition)
            $URI += "?conditions=$Condition"
        }

        if($Arguments.childconditions) {
            $childconditions = [System.Web.HttpUtility]::UrlEncode($Arguments.childconditions)
            $URI += "&childconditions=$childconditions"
        }

        if($Arguments.customfieldconditions) {
            $customfieldconditions = [System.Web.HttpUtility]::UrlEncode($Arguments.customfieldconditions)
            $URI += "&customfieldconditions=$customfieldconditions"
        }

        if($Arguments.orderBy) {$URI += "&orderBy=$($Arguments.orderBy)"}
        
        $WebRequestArguments = @{
            Uri = $URI
            Method = 'GET'
        }

        if ($Arguments.all) {
            $Result = Invoke-CWMAllResult -Arguments $WebRequestArguments
        }
        else {
            if($Arguments.pageSize){$WebRequestArguments.URI += "&pageSize=$pageSize"}
            if($Arguments.page){$WebRequestArguments.URI += "&page=$page"}
            $Result = Invoke-CWMWebRequest -Arguments $WebRequestArguments
            if($Result.content){
                try{
                    $Result = $Result.content | ConvertFrom-Json
                }
                catch{}                
            }
        }
        return $Result
    }
    function Invoke-CWMSearchMaster {
        <#
            .SYNOPSIS
            This will be basis of all search calls to the ConnectWise Manage API.
                
            .DESCRIPTION
            This will insure that all search requests are handled correctly.
                
            .PARAMETER Arguments
            A hash table of parameters

            .PARAMETER URI
            The URI of the search endpoint
                                
            .EXAMPLE
            Invoke-CWMSearchMaster -Arguments $Arguments -URI $URI
                
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018

            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/Manage/Developer_Guide#Authentication
        #>
        [CmdletBinding()]
        param (
            $Arguments,
            [string]$URI
        )
    
        $Body = @{}
        switch ($Arguments.Keys) {
            'conditions'               { $Body.conditions               = $Arguments.conditions               }
            'orderBy'                  { $Body.orderBy                  = $Arguments.orderBy                  }
            'childconditions'          { $Body.childconditions          = $Arguments.childconditions          }
            'customfieldconditions'    { $Body.customfieldconditions    = $Arguments.customfieldconditions    }                       
        }
        $Body = $($Body | ConvertTo-Json)
        Write-Verbose $Body

        $WebRequestArguments = @{
            Uri = $URI
            Method = 'Post'
            ContentType = 'application/json'
            Body = $Body
            Headers = $Global:CWMServerConnection.Headers
        }

        if ($Arguments.all) {
            $Result = Invoke-CWMAllResult -Arguments $WebRequestArguments
        } 
        else {    
            if($Arguments.pageSize){$WebRequestArguments.URI += "&pageSize=$pageSize"}
            if($Arguments.page){$WebRequestArguments.URI += "&page=$page"}
            $Result = Invoke-CWMWebRequest -Arguments $WebRequestArguments
            if($Result.content){
                $Result = $Result.content | ConvertFrom-Json
            }
        }
        return $Result
    }
    function Invoke-CWMDeleteMaster {
        <#
            .SYNOPSIS
            This will be basis of all delete calls to the ConnectWise Manage API.
                
            .DESCRIPTION
            This will insure that all delete requests are handled correctly.
                
            .PARAMETER Arguments
            A hash table of parameters

            .PARAMETER URI
            The URI of the delete endpoint
                                
            .EXAMPLE
            Invoke-CWMDeleteMaster -Arguments $Arguments -URI $URI
                
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018

            .LINK
            http://labtechconsulting.com
        #>
        [CmdletBinding()]
        param (
            $Arguments,
            [string]$URI
        )

        $WebRequestArguments = @{
            Uri = $URI
            Method = 'Delete'
        }
        $Result = Invoke-CWMWebRequest -Arguments $WebRequestArguments
        if($Result.content){
            $Result = $Result.content | ConvertFrom-Json
        }
        return $Result
    }
    function Invoke-CWMUpdateMaster {
        <#
            .SYNOPSIS
            This will be basis of all update calls to the ConnectWise Manage API.
                
            .DESCRIPTION
            This will insure that all update requests are handled correctly.
                
            .PARAMETER Arguments
            A hash table of parameters

            .PARAMETER URI
            The URI of the update endpoint
                                
            .EXAMPLE
            Invoke-CWMUpdateMaster -Arguments $Arguments -URI $URI
                
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018

            .LINK
            http://labtechconsulting.com
        #>
        [CmdletBinding()]
        param (
            $Arguments,
            [string]$URI
        )

        $Body =@(
            @{            
                op = $Arguments.Operation
                path = $Arguments.Path
                value = $Arguments.Value      
            }
        )
        $Body = $(ConvertTo-Json $Body)
        Write-Verbose $Body

        $WebRequestArguments = @{
            Uri = $URI
            Method = 'Patch'
            ContentType = 'application/json'
            Body = $Body
        }
        $Result = Invoke-CWMWebRequest -Arguments $WebRequestArguments
        if($Result.content){
            $Result = $Result.content | ConvertFrom-Json
        }
        return $Result
    }
    function Invoke-CWMNewMaster {
        <#
            .SYNOPSIS
            This will be basis of all create calls to the ConnectWise Manage API.
                
            .DESCRIPTION
            This will insure that all create requests are handled correctly.
                
            .PARAMETER Arguments
            A hash table of parameters

            .PARAMETER URI
            The URI of the create endpoint
                                
            .EXAMPLE
            Invoke-CWMUpdateMaster -Arguments $Arguments -URI $URI
                
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018

            .LINK
            http://labtechconsulting.com
        #>
        [CmdletBinding()]
        param (
            $Arguments,
            [string]$URI,
            [string[]]$Skip
        )
        # Skip common parameterss
        $Skip += 'Debug','ErrorAction','ErrorVariable','InformationAction','InformationVariable','OutVariable','OutBuffer','PipelineVariable','Verbose','WarningAction','WarningVariable','WhatIf','Confirm'
        
        $Body = @{}
        foreach($i in $Arguments.GetEnumerator()){ 
            if($Skip -notcontains $i.Key){
                $Body.Add($i.Key, $i.value) 
            } 
        }
        $Body = ConvertTo-Json $Body -Depth 10 
        Write-Verbose $Body

        $WebRequestArguments = @{
            Uri = $URI
            Method = 'Post'
            ContentType = 'application/json'
            Body = $Body
        }
        $Result = Invoke-CWMWebRequest -Arguments $WebRequestArguments
        if($Result.content){
            $Result = $Result.content | ConvertFrom-Json
        }
        return $Result
    }
    function Invoke-CWMAllResult {
        <#
            .SYNOPSIS
            This will handel web requests for all results to the ConnectWise Manage API.
                
            .DESCRIPTION
            This will enable forward only pagination and loop all results.
                
            .PARAMETER Arguments
            A hash table of parameters
                    
            .EXAMPLE
            Invoke-CWMAllResult -Arguments $Arguments
                
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018

            .LINK
            http://labtechconsulting.com
        #>
        [CmdletBinding()]
        param(
            $Arguments
        )
    
        # Update header for new pagination-type
        $Arguments.Headers += @{
            'pagination-type' = 'forward-only'
        }             
    
        # Up the pagesize to max
        $URI += "&pageSize=999"
    
        # First request
        $PageResult = Invoke-CWMWebRequest -Arguments $Arguments
        if (!$PageResult){return}
        if(!$PageResult.Headers.Link){
            Write-Error "The $((Get-PSCallStack)[2].Command) Endpoint doesn't support 'forward-only' pagination. Please report to ConnectWise."
            return
        }
        $NextPage = $PageResult.Headers.Link.Split(';')[0].trimstart('<').trimend('>')
        $Collection = @()
        $Collection += $PageResult.Content | ConvertFrom-Json
        
        # Loop through all results
        while ($NextPage) {
            $Arguments.Uri = $NextPage
            $PageResult = Invoke-CWMWebRequest -Arguments $Arguments
            if (!$PageResult){return}
            $Collection += $PageResult.Content | ConvertFrom-Json
            $NextPage = $PageResult.Headers.Link.Split(';')[0].trimstart('<').trimend('>')
        }
        return $Collection
    }
    function Invoke-CWMWebRequest {
        <#
            .SYNOPSIS
            This function is used to handle all web requests to the ConnectWise Manage API.
            
            .DESCRIPTION
            This function is used to manage error handling with web requests.
            It will also handle retries of failed attempts.

            .PARAMETER Arguments
            A splat object of web request parameters

            .PARAMETER MaxRetry
            The maximum number of retry attempts

            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018

            .LINK
            http://labtechconsulting.com
        #>
        [CmdletBinding()]
        param(
            $Arguments,
            [int]$MaxRetry = 5
        )

        # Check that we have cached connection info
        if(!$global:CWMServerConnection){
            $ErrorMessage = @()
            $ErrorMessage += "Not connected to a Manage server."
            $ErrorMessage +=  $_.ScriptStackTrace
            $ErrorMessage += ''    
            $ErrorMessage += '--> $CWMServerConnection variable not found.'
            $ErrorMessage += "----> Run 'Connect-CWM' to initialize the connection before issuing other CWM commandlets."
            Write-Error ($ErrorMessage | Out-String)
            return
        }
        
        # Add default set of arguments
        foreach($Key in $Global:CWMServerConnection.Headers.Keys){
            if($Arguments.Headers.Keys -notcontains $Key){
                $Arguments.Headers += @{$Key = $Global:CWMServerConnection.Headers.$Key}
            }
        }
        if(!$Arguments.SessionVariable){ $Arguments.WebSession = $global:CWMServerConnection.Session }

        # Check URI format
        if($Arguments.URI -notlike '*`?*' -and $Arguments.URI -like '*`&*') {
            $Arguments.URI = $Arguments.URI -replace '(.*?)&(.*)', '$1?$2'
        }        
        # Issue request
        try {
            $Result = Invoke-WebRequest @Arguments -UseBasicParsing
        } 
        catch {
            # Read exception response
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $global:errBody = $reader.ReadToEnd() | ConvertFrom-Json
            
            # Start error message
            $ErrorMessage = @()

            if($errBody.code){
                $ErrorMessage += "An exception has been thrown."
                $ErrorMessage +=  $_.ScriptStackTrace
                $ErrorMessage += ''    
                $ErrorMessage += "--> $($errBody.code)"
                if($errBody.code -eq 'Unauthorized'){
                    $ErrorMessage += "-----> $($errBody.message)"
                    $ErrorMessage += "-----> Use 'Disconnect-CWM' or 'Connect-CWM -Force' to set new authentication."
                } 
                else {
                    $ErrorMessage += "-----> $($errBody.message)"
                    $ErrorMessage += "-----> ^ Error has not been documented please report. ^"
                }    
            }

            if ($_.ErrorDetails) {
                $ErrorMessage += "An error has been thrown."
                $ErrorMessage +=  $_.ScriptStackTrace
                $ErrorMessage += ''
                $global:errDetails = $_.ErrorDetails | ConvertFrom-Json
                $ErrorMessage += "--> $($errDetails.code)"
                $ErrorMessage += "-----> $($errDetails.message)"
                if($errDetails.code -eq 'InvalidObject' -and $Arguments.Method -eq 'Patch'){
                    $ErrorMessage += "-----> Check length of strings"
                }
            }
                        
            Write-Error ($ErrorMessage | out-string)
            return
        }
        
        # Not sure this will be hit with current iwr error handling
        # May need to move to catch block need to find test
        # TODO Find test for retry
        # Retry the request
        $Retry = 0
        while ($Retry -lt $MaxRetry -and $Result.StatusCode -notin (200,201,400)) {
            $Retry++
            # ConnectWise Manage recommended wait time
            $Wait = $([math]::pow( 2, $Retry))
            Write-Warning "Issue with request, status: $($Result.StatusCode) $($Result.StatusDescription)"
            Write-Warning "$($Retry)/$($MaxRetry) retries, waiting $($Wait)ms."
            Start-Sleep -Milliseconds $Wait
            $Result = Invoke-WebRequest @Arguments -UseBasicParsing
        }
        if ($Retry -ge $MaxRetry) {
            Write-Error "Max retries hit. Status: $($Result.StatusCode) $($Result.StatusDescription)"
            return
        }
        return $Result
    }
#endregion [Helpers]-------

#region [Company]-------
  #region [Companies]-------
    function Get-CWMCompany {
        <#
            .SYNOPSIS
            This function will list companies based on conditions.
                
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results

            .EXAMPLE
            Get-CWMCompany -Condition "status/id IN (1,42,43,57)" -all
            Will return all companies that match the condition

            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018

            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Company&e=Companies&o=GET  
        #>
        [CmdletBinding()]
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )

        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/company/companies"

        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI            
    }
    function Update-CWMCompany {
        <#
            .SYNOPSIS
            This will update a company.
                
            .PARAMETER CompanyID
            The ID of the company that you are updating. Get-CWMCompanies

            .PARAMETER Operation
            What you are doing with the value. 
            replace, add, remove

            .PARAMETER Path
            The value that you want to perform the operation on.

            .PARAMETER Value
            The value of path.

            .EXAMPLE
            $UpdateParam = @{
                CompanyID = $Company.id
                Operation = 'replace'
                Path = 'name'
                Value = $NewName
            }
            Update-CWMCompany @UpdateParam

            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
            
            .LINK
            http://labtechconsulting.com
            https://service.itnow.net/v4_6_release/services/apitools/apidocumentation/?a=Company&e=Companies&o=UPDATE
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            $CompanyID,
            [Parameter(Mandatory=$true)]
            [validateset('add','replace','remove')]
            $Operation,
            [Parameter(Mandatory=$true)]
            [string]$Path,
            [Parameter(Mandatory=$true)]
            [string]$Value
        )

        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/company/companies/$CompanyID"
        return Invoke-CWMUpdateMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [Companies]-------
  #region [Contacts]-------
    function Get-CWMContact {
    <#
    .SYNOPSIS
        This function will list contacts.
        
        .PARAMETER Condition
        This is your search condition to return the results you desire.
        Example:
        (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

        .PARAMETER orderBy
        Choose which field to sort the results by

        .PARAMETER childconditions
        Allows searching arrays on endpoints that list childConditions under parameters

        .PARAMETER customfieldconditions
        Allows searching custom fields when customFieldConditions is listed in the parameters

        .PARAMETER page
        Used in pagination to cycle through results

        .PARAMETER pageSize
        Number of results returned per page (Defaults to 25)
        
        .PARAMETER all
        Return all results

        .EXAMPLE
        Get-CWMContact -Condition 'firstName = "Chris"' -all
        Will list all users with the first name of Chris.
        
        .NOTES
        Author: Chris Taylor
        Date: 10/10/2018

        .LINK
        http://labtechconsulting.com
        https://developer.connectwise.com/manage/rest?a=Company&e=Contacts&o=GET
    #>
    [CmdletBinding()]
    param(
        [string]$Condition,
        [ValidateSet('asc','desc')] 
        $orderBy,
        [string]$childconditions,
        [string]$customfieldconditions,
        [int]$page,
        [int]$pageSize,
        [switch]$all
    )

    $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/company/contacts"
    
    return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI            
}
    function New-CWMContact {
        <#
            .SYNOPSIS
            This function will create a new contact.
        
            .EXAMPLE
            New-CWMContact -firstName 'Chris' -lastName 'Taylor' -company @{id = $Company.id}
                Create a new contact.
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Company&e=Contacts&o=CREATE    
        #>
        [CmdletBinding()]
        param(
            [int]$id,
            [Parameter(Mandatory=$true)]
            [ValidateLength(1,30)]
            [string]$firstName,
            [ValidateLength(1,30)]
            [string]$lastName,
            $type,
            $company,
            $site,
            [ValidateLength(1,50)]
            [string]$addressLine1,
            [ValidateLength(1,50)]
            [string]$addressLine2,
            [ValidateLength(1,50)]
            [string]$city,
            [ValidateLength(1,50)]
            [string]$state,
            [ValidateLength(1,12)]
            [string]$zip,
            [ValidateLength(1,50)]
            [string]$country,
            $relationship,
            $department,
            [bool]$inactiveFlag,
            [int]$defaultMergeContactId,
            [ValidateLength(1,184)]
            [string]$securityIdentifier,
            [int]$managerContactId,
            [int]$assistantContactId,
            [ValidateLength(1,100)]
            [string]$title,
            [ValidateLength(1,50)]
            [string]$school,
            [ValidateLength(1,30)]
            [string]$nickName,
            [bool]$marriedFlag,
            [bool]$childrenFlag,
            [ValidateLength(1,30)]
            [string]$significantOther,
            [ValidateLength(1,15)]
            [string]$portalPassword,
            [int]$portalSecurityLevel,
            [bool]$disablePortalLoginFlag,
            [bool]$unsubscribeFlag,
            $gender,
            [string]$birthDay,
            [string]$anniversary,
            $presence,
            [GUID]$mobileGuid,
            [string]$facebookUrl,
            [string]$twitterUrl,
            [string]$linkedInUrl,
            [bool]$defaultBillingFlag,
            [bool]$defaultFlag,
            $communicationItems,
            $_info,
            $customFields
        )
            
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/company/contacts"
        return Invoke-CWMNewMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [Contacts]-------
  #region [Configurations]-------
    function Get-CWMCompanyConfiguration {
        <#
            .SYNOPSIS
            This function will list all CW company configurations.
            
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results

            .EXAMPLE
            Get-CWMCompanyConfiguration -all
            Will list all configurations.
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018

            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Company&e=Configurations&o=GET
        #>
        [CmdletBinding()]
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )

        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/company/configurations"

        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI            
    }
    function Remove-CWMCompanyConfiguration {
        <#
            .SYNOPSIS
            This function will remove a company configuration from Manage.
                
            .PARAMETER CompanyID
            The ID of the company configuration that you want to delete.

            .EXAMPLE
            Remove-CWMCompanyConfiguration -CompanyConfigurationID 123

            .NOTES
            Author: Chris Taylor
            Date: 7/3/2017

            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Company&e=Configurations&o=DELETE
        #>
        [CmdletBinding()]
        param(
            [int]$CompanyConfigurationID
        )

        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/company/configurations/$CompanyConfigurationID"
        return Invoke-CWMDeleteMaster -Arguments $PsBoundParameters -URI $URI            
    }
  #endregion [Configurations]-------
  #region [CompanyStatuses]-------
    function Get-CWMCompanyStatus {
        <#
            .SYNOPSIS
            This function will list all CW company statuses.

            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results

            .EXAMPLE
            Get-CWMCompanyStatus -all
            Will list all Company Statuses.

            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018

            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Company&e=CompanyStatuses&o=GET
        #>
        [CmdletBinding()]
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )

        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/company/companies/statuses"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [CompanyStatuses]-------
  #region [CompanyTeams]-------
    function New-CWMCompanyTeam {
        <#
            .SYNOPSIS
            This function will create a new ticket.
        
            .EXAMPLE
            $Ticket = @{
                'identifier' = $Product.offerName
                'description' = $Product.offerName
                'subcategory' = @{id = 152}
                'type' = @{id = 47}
                'customerDescription' = $Product.offerName
                'cost' = $Product.unitPrice
                'price' = $Price
                'manufacturerPartNumber' = $Product.offerName
                'manufacturer' = $Manufacturer
                'productClass' = 'Agreement'
                'taxableFlag' = $true
            }
            New-CWTicket @Ticket
            
            .NOTES
            Author: Chris Taylor
            Date: 8/22/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Company&e=CompanyTeams&o=CREATE    
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            $CompanyID,
            [int]$id,
            $company,
            [Parameter(Mandatory=$true)]
            $teamRole,
            [int]$locationId,
            [int]$businessUnitId,
            $contact,
            $member,
            [boolean]$accountManagerFlag,
            [boolean]$techFlag,
            [boolean]$salesFlag,
            $_info
        )

        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/company/companies/$CompanyID/teams"
        $Skip = 'CompanyID'
        return Invoke-CWMNewMaster -Arguments $PsBoundParameters -URI $URI -Skip $Skip          
    }
    function Get-CWMCompanyTeam {
        <#
            .SYNOPSIS
            This function will list of teams of a company based on conditions.
                
            .PARAMETER Condition
            The id of the company you want to get the teams of.
            
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"
            
            .PARAMETER orderBy
            Choose which field to sort the results by
            
            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters
            
            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters
            
            .PARAMETER page
            Used in pagination to cycle through results
            
            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)
            
            .PARAMETER all
            Return all results
            
            .EXAMPLE
            Get-CWMCompanyTeam -CompanyID 1 -all
            Will return all team members for company 1
            
            .NOTES
            Author: Chris Taylor
            Date: 10/25/2018
            
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=Company&e=CompanyTeams&o=GET  
        #>
        [CmdletBinding()]
        param(
            [int]$CompanyID,
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/company/companies/$($CompanyID)/teams"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI            
    }
  #endregion [CompanyTeams]-------
  #region [TeamRoles]-------
    function Get-CWMCompanyTeamRole {
        <#
            .SYNOPSIS
            This function will list company team roles.
            
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results
        
            .EXAMPLE
            Get-CWMCompanyTeamRole -all
            Will list all company team roles.
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=Company&e=TeamRoles&o=GET
            #>
        [CmdletBinding()]
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
            )
        
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/company/teamRoles"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
        }
  #endregion [TeamRoles]-------
  #region [CompanyTypes]-------
    function Get-CWMCompanyType {
        <#
            .SYNOPSIS
            This function will list company types.
            
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results
        
            .EXAMPLE
            Get-CWCompanyType -all
            Will list all company types.
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=Company&e=CompanyTypes&o=GET
        #>
        [CmdletBinding()]
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
            )
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/company/companies/types"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [CompanyTypes]-------
  #region [CompanyCompanyTypeAssociations]-------
    function Get-CWMCompanyTypeAssociation {
        <#
            .SYNOPSIS
            This function will list all types associated with a company.
            
            .PARAMETER CompanyID
            The id of the company to retrieve types.

            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results
        
            .EXAMPLE
            Get-CWMCompanyTypeAssociation -CompanyID 1 -all
            Will list all types associated with company 1.
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=Company&e=CompanyCompanyTypeAssociations&o=GET
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [int]$CompanyID,
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/company/companies/$CompanyID/typeAssociations"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
    function New-CWMCompanyTypeAssociation {
        <#
            .SYNOPSIS
            Creates a new type association for a company        
            
            .EXAMPLE
            New-CWMCompanyTypeAssociation -CompanyID 4385 -Type @{type = @{id = 68}}
            Adds the type 68 to company 4385
            .NOTES
            Author: Chris Taylor
            Date: 8/22/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=Company&e=CompanyCompanyTypeAssociations&o=CREATE    
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [int]$CompanyID,
            $Type
        )

        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/company/companies/$CompanyID/typeAssociations"
        $Skip ='CompanyID'
        return Invoke-CWMNewMaster -Arguments $PsBoundParameters -URI $URI -Skip $Skip          
    }
    function Remove-CWMCompanyTypeAssociation {
        <#
            .SYNOPSIS
            This function will remove a type from a company.
        
            .PARAMETER CompanyID
            The ID of the company configuration that you want to delete.

            .PARAMETER TypeAssociationID
            The ID of the company configuration that you want to delete.

            .EXAMPLE
            Remove-CWMCompanyConfiguration -CompanyConfigurationID 123

            .NOTES
            Author: Chris Taylor
            Date: 7/3/2017

            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/Products/Manage/REST?a=Company&e=CompanyCompanyTypeAssociations&o=DELETE
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [int]$CompanyID,
            [Parameter(Mandatory=$true)]
            [int]$TypeAssociationID
        )

        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/company/companies/$CompanyID/typeAssociations/$TypeAssociationID"
        return Invoke-CWMDeleteMaster -Arguments $PsBoundParameters -URI $URI            
    }
    function Update-CWMCompanyTypeAssociation {
        <#
            .SYNOPSIS
            This will update a company type association.
        
            .PARAMETER CompanyID
            The ID of the company that you are updating. Get-CWMCompanies

            .PARAMETER TypeAssociationID
            The TypeAssociationID of the company that you are updating. Get-CWMCompanyTypeAssociation

            .PARAMETER Operation
            What you are doing with the value. 
            replace

            .PARAMETER Path
            The value that you want to perform the operation on.

            .PARAMETER Value
            The value of that operation.

            .EXAMPLE
            $UpdateParam = @{
                CompanyID = $Company.id
                TypeAssociationID = $TypeAssoc.id
                Operation = 'replace'
                Path = 'name'
                Value = $NewName
            }
            Update-CWMCompanyTypeAssociation @UpdateParam

            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
    
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/Products/Manage/REST?a=Company&e=CompanyCompanyTypeAssociations&o=UPDATE
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [int]$CompanyID,
            [Parameter(Mandatory=$true)]
            [int]$TypeAssociationID,
            [Parameter(Mandatory=$true)]
            [validateset('add','replace','remove')]
            $Operation,
            [Parameter(Mandatory=$true)]
            [string]$Path,
            [Parameter(Mandatory=$true)]
            [string]$Value
        )

        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/company/companies/$CompanyID/typeAssociations/$TypeAssociationID"   
        return Invoke-CWMUpdateMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [CompanyCompanyTypeAssociations]-------
#endregion [Company]-------

#region [Expense]-------
#endregion [Expense]-------

#region [Finance]-------
  #region [AgreementAdditions]-------
    function Get-CWMAgreementAddition {
        <#
            .SYNOPSIS
            This function will list additions to a Manage agreements.
                
            .PARAMETER AgreementID
            The agreement ID of the agreement the addition belongs to.

            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results        
            
            .EXAMPLE
            Get-CWMAgreementAddition -AgreementID $Agreement.id -all
            Will list all agreement additions for the given agreement.
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018

            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Finance&e=AgreementAdditions&o=GET
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            $AgreementID,
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )

        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/finance/agreements/$AgreementID/additions?"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
    function Update-CWMAgreementAddition {
        <#
            .SYNOPSIS
            This will update an addition to an agreement.
                
            .PARAMETER AgreementID
            The ID of the agreement that you are updating. Get-CWMAgreement

            .PARAMETER AdditionID
            The ID of the addition that you are updating. Get-CWMAddition

            .PARAMETER Operation
            What you are doing with the value. 
            add, replace, remove

            .PARAMETER Path
            The value that you want to perform the operation on.

            .PARAMETER Value
            The value of that operation.

            .EXAMPLE
            $UpdateParam = @{
                AgreementID = $Agreement.id
                AdditionID = $Addition.id
                Operation = 'replace'
                Path = 'quantity'
                Value = $UmbrellaCount
            }
            Update-CWMAgreementAddition @UpdateParam

            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
            
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Finance&e=AgreementAdditions&o=UPDATE
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [int]$AgreementID,
            [Parameter(Mandatory=$true)]
            [int]$AdditionID,
            [Parameter(Mandatory=$true)]
            [validateset('add','replace','remove')]
            $Operation,
            [Parameter(Mandatory=$true)]
            [string]$Path,
            [Parameter(Mandatory=$true)]
            [string]$Value
        )

        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/finance/agreements/$AgreementID/additions/$AdditionID"
        return Invoke-CWMUpdateMaster -Arguments $PsBoundParameters -URI $URI
    }
    function New-CWMAgreementAddition {
        <#
            .SYNOPSIS
            This function will create a new agreement addition.

            .EXAMPLE
            $CreateParam = @{
                AgreementID = $Agreement.id
                product = @{id = $Product.id}
                billCustomer = 'DoNotBill'
                quantity = $Quantity
                taxableFlag = $true
                effectiveDate = $(Get-Date (Get-Date -Day 1).AddMonths(1) -format yyyy-MM-ddTHH:mm:ssZ)
            }
            New-CWMAgreementAddition @CreateParam

            
            .NOTES
            Author: Chris Taylor
            Date: 4/2/2018

            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Finance&e=AgreementAdditions&o=CREATE
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [int]$AgreementID,
            [int]$id,
            [Parameter(Mandatory=$true)]
            $product,
            [float]$quantity,
            [float]$lessIncluded,
            [float]$unitPrice,
            [float]$unitCost,
            [Parameter(Mandatory=$true)]
            [ValidateSet('Billable', 'DoNotBill', 'NoCharge')]
            $billCustomer,
            [string]$effectiveDate,
            [string]$cancelledDate,
            [bool]$taxableFlag,
            [ValidateLength(1,50)]
            [string]$serialNumber,
            [ValidateLength(1,6000)]
            [string]$invoiceDescription,
            [bool]$purchaseItemFlag,
            [bool]$specialOrderFlag,
            [string]$description,
            [float]$billedQuantity,
            [string]$uom,
            [float]$extPrice,
            [float]$extCost,
            [float]$sequenceNumber,
            [float]$margin,
            [float]$prorateCost,
            [float]$proratePrice,
            [float]$extendedProrateCost,
            [float]$extendedProratePrice,
            [bool]$prorateCurrentPeriodFlag,
            $_info
        )
        
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/finance/agreements/$AgreementID/additions"
        $Skip = 'AgreementID'
        return Invoke-CWMNewMaster -Arguments $PsBoundParameters -URI $URI -Skip $Skip          
    }
  #endregion [AgreementAdditions]-------
  #region [Agreements]-------
    function Get-CWMAgreement {
        <#
            .SYNOPSIS
            This function will list agreements based on conditions.
                
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results
        
            .EXAMPLE
            Get-CWMAgreement -Condition "company/identifier=`"$($Config.company.identifier)`" AND parentagreementid = null"
            Will list the agreements that match the condition.

            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Finance&e=Agreements&o=GET    
        #>
        [CmdletBinding()]
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/finance/agreements"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [Agreements]-------
#endregion [Finance]-------

#region [Marketing]-------
#endregion [Marketing]-------

#region [Procurement]-------
  #region [ProductTypes]-------
    function Get-CWMProductType {
        <#
            .SYNOPSIS
            This function will list product types.
            
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results

            .EXAMPLE
            Get-CWMProductType -all
            Will list all product types.
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018

            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Procurement&e=ProductTypes&o=GET
        #>
        [CmdletBinding()]
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )

        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/procurement/types"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [ProductTypes]-------
  #region [ProductComponents]-------
    function Get-CWMProductComponent {
        <#
            .SYNOPSIS
            This function will list a products components.
            
            .PARAMETER ProductID
            The ID of the product that you want to get the components of.
        
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results
        
            .EXAMPLE
            Get-CWMProductComponent -ID 555 -all
            Will list all product components for product 555.
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Procurement&e=ProductComponents&o=GET    
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [int]$ProductID,
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
            )
        if(!$global:CWMServerConnection){
            Write-Error "Not connected to a Manage server. Run Connect-CWM first."
            break
        }
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/procurement/products/$($ProductID)/components"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [ProductComponents]-------
  #region [ProductsItem]-------
    function Get-CWMProduct {
        <#
            .SYNOPSIS
            This function will list all CW products.
            
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results
        
            .EXAMPLE
            Get-CWMProducts -all
            Will list all products.
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Procurement&e=ProductsItem&o=GET
        #>
        [CmdletBinding()]
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/procurement/products"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [ProductsItem]-------
  #region [CatalogsItem]-------
    function Get-CWMProductCatalog {
        <#
            .SYNOPSIS
            This function will list the product catalogs.
            
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results
        
            .EXAMPLE
            Get-CWMProductCatalog -all
            Will list all catalogs.
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Procurement&e=CatalogsItem&o=GET
        #>
        [CmdletBinding()]
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/procurement/catalog"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
    function New-CWMProductCatalog {
        <#
            .SYNOPSIS
            This function will create a new catalog.
        
            .EXAMPLE
            $Catalog = @{
                'identifier' = $Product.offerName
                'description' = $Product.offerName
                'subcategory' = @{id = 152}
                'type' = @{id = 47}
                'customerDescription' = $Product.offerName
                'cost' = $Product.unitPrice
                'price' = $Price
                'manufacturerPartNumber' = $Product.offerName
                'manufacturer' = $Manufacturer
                'productClass' = 'Agreement'
                'taxableFlag' = $true
            }
            New-CWMCatalog @Catalog
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Procurement&e=CatalogsItem&o=CREATE    
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [ValidateLength(1,60)]
            [string]$identifier,
            [Parameter(Mandatory=$true)]
            [ValidateLength(1,50)]
            [string]$description,
            [bool]$inactiveFlag,
            [Parameter(Mandatory=$true)]
            $subcategory,
            [Parameter(Mandatory=$true)]
            $type,
            [ValidateSet('Agreement', 'Bundle', 'Inventory', 'NonInventory', 'Service')]
            [string]$productClass,
            [bool]$serializedFlag,
            [bool]$serializedCostFlag,
            [bool]$phaseProductFlag,
            $unitOfMeasure,
            [int]$minStockLevel,
            [float]$price,
            [float]$cost,
            [int]$priceAttribute,
            [bool]$taxableFlag,
            [Parameter(Mandatory=$true)]
            [ValidateLength(1,6000)]
            [string]$customerDescription,
            $manufacturer,
            [ValidateLength(1,50)]
            [string]$manufacturerPartNumber,
            $vendor,
            [ValidateLength(1,50)]
            [string]$vendorSku,
            [string]$notes,
            [ValidateLength(1,50)]
            [string]$integrationXRef,
            [string]$dateEntered,
            $category,
            $_info,
            $customFields
        )
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/procurement/catalog"
        return Invoke-CWMNewMaster -Arguments $PsBoundParameters -URI $URI   
    }
    function Update-CWMProductCatalog {
        <#
            .SYNOPSIS
            This will update a catalog item.
                
            .PARAMETER CatalogID
            The ID of the catalog that you are updating. Get-CWMCatalogs
        
            .PARAMETER Operation
            What you are doing with the value. 
            replace
        
            .PARAMETER Path
            The value that you want to perform the operation on.
        
            .PARAMETER Value
            The value of that operation.
        
            .EXAMPLE
            $Update = @{
                CatalogID = $testProduct.id
                Operation = 'replace'
                Path      = 'price'
                Value     = $Price                            
            }
            Update-CWMCatalog @Update
        
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
            
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Procurement&e=CatalogsItem&o=UPDATE    
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            $CatalogID,
            [Parameter(Mandatory=$true)]
            $Operation,
            [Parameter(Mandatory=$true)]
            $Path,
            [Parameter(Mandatory=$true)]
            $Value
        )
                
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/procurement/catalog/$CatalogID"
        return Invoke-CWMUpdateMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [CatalogsItem]-------
  #region [SubCategories]-------
    function Get-CWMProductSubCategory {
        <#
            .SYNOPSIS
            This function will list the product sub categories.
            
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results
        
            .EXAMPLE
            Get-CWMProductSubCategory -all
            Will list all sub categories.
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Procurement&e=SubCategories&o=GET
        #>
        [CmdletBinding()]
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/procurement/subcategories"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [SubCategories]-------
  #region [Manufacturers]-------
    function Get-CWMManufacturer {
        <#
            .SYNOPSIS
            This function will allow you to search for Manage manufacturers.
        
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results
        
            .EXAMPLE
            Get-CWMManufacturer -Condition "name=`"$Name`""
            This will return all the manufacturers with a name that matches $Name
        
            .NOTES
            Author: Chris Taylor
            Date: 3/22/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Procurement&e=Manufacturers&o=GET
        #>        
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/procurement/manufacturers"
    
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [Manufacturers]-------
#endregion [Procurement]-------

#region [Project]-------
  #region [Projects]-------
    function Get-CWMProject {
        <#
            .SYNOPSIS
            This function will list all CW Projects.
            
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results

            .EXAMPLE
            Get-CWMProject -all
            Will list all Projects.
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Project&e=Projects&o=GET
        #>
        [CmdletBinding()]
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/project/projects"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [Projects]-------
  #region [ProjectSecurityRoles]-------
    function Get-CWMProjectSecurityRole {
        <#
            .SYNOPSIS
            This function will list project security roles.
            
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results
        
            .EXAMPLE
            Get-CWMProjectSecurityRole -all
            Will list all project security roles.
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=Project&e=ProjectSecurityRoles&o=GET
        #>
        [CmdletBinding()]
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/project/securityRoles"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [ProjectSecurityRoles]-------
  #region [ProjectPhases]-------
    function Update-CWMProjectPhase {
        <#
            .SYNOPSIS
            This will update an project phase.
                
            .PARAMETER ProjectID
            The ID of the project that you are updating. List-CWProjects
        
            .PARAMETER PhaseID
            The ID of the phase that you are updating. Get-CWProjectPhases
        
            .PARAMETER Operation
            What you are doing with the value. 
            replace
        
            .PARAMETER Path
            The value that you want to perform the operation on.
        
            .PARAMETER Value
            The value of that operation.
        
            .EXAMPLE
            $UpdateParam = @{
                ProjectID = $Project.id
                PhaseID = $Phase.id
                Operation = 'replace'
                Path = 'status'
                Value = $Value
            }
            Update-CWProjectPhase @UpdateParam
        
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
            
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=Project&e=ProjectPhases&o=UPDATE
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            $ProjectID,
            [Parameter(Mandatory=$true)]
            $PhaseID,
            [Parameter(Mandatory=$true)]
            [validateset('add','replace','remove')]
            $Operation,
            [Parameter(Mandatory=$true)]
            [string]$Path,
            [Parameter(Mandatory=$true)]
            [string]$Value
        )
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/project/projects/$ProjectID/phases/$PhaseID"
        return Invoke-CWMUpdateMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [ProjectPhases]-------
  #region [ProjectsTeamMembers]-------
    function Get-CWMProjectTeamMember {
        <#
            .SYNOPSIS
            This function will list team members of a project.
        
            .PARAMETER ProjectID
            The ID of the project you want team members from.
            
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results

            .EXAMPLE
            Get-CWMProjectTeamMember -ProjectID 1 -all
            Will list all project team members for project 1.
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=Project&e=ProjectBoardTeamMembers&o=GET
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [int]$ProjectID,
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/project/projects/$ProjectID/teamMembers"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
    function New-CWMProjectTeamMember {
        <#
            .SYNOPSIS
            This function will create a new ticket.
        
            .EXAMPLE
            $Ticket = @{
                'identifier' = $Product.offerName
                'description' = $Product.offerName
                'subcategory' = @{id = 152}
                'type' = @{id = 47}
                'customerDescription' = $Product.offerName
                'cost' = $Product.unitPrice
                'price' = $Price
                'manufacturerPartNumber' = $Product.offerName
                'manufacturer' = $Manufacturer
                'productClass' = 'Agreement'
                'taxableFlag' = $true
            }
            New-CWTicket @Ticket
            
            .NOTES
            Author: Chris Taylor
            Date: 8/22/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=Project&e=ProjectsTeamMembers&o=CREATE    
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [int]$ProjectID,
            [int]$id,
            [decimal]$hours,
            [Parameter(Mandatory=$true)]
            $member,
            [Parameter(Mandatory=$true)]
            $projectRole,
            $workRole,
            [string]$startDate,
            [string]$endDate,
            $_info
        )
            
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/project/projects/$ProjectID/teamMembers"
        return Invoke-CWMNewMaster -Arguments $PsBoundParameters -URI $URI        
    }
  #endregion [ProjectsTeamMembers]-------
#endregion [Project]-------

#region [Sales]-------
#endregion [Sales]-------

#region [Schedule]-------
  #region [ScheduleEntries]-------
    function Get-CWMScheduleEntry {
        <#
        .SYNOPSIS
        This function will list members schedules.
        
        .PARAMETER Condition
        This is your search condition to return the results you desire.
        Example:
        (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

        .PARAMETER orderBy
        Choose which field to sort the results by

        .PARAMETER childconditions
        Allows searching arrays on endpoints that list childConditions under parameters

        .PARAMETER customfieldconditions
        Allows searching custom fields when customFieldConditions is listed in the parameters

        .PARAMETER page
        Used in pagination to cycle through results

        .PARAMETER pageSize
        Number of results returned per page (Defaults to 25)

        .PARAMETER all
        Return all results
    
        .EXAMPLE
        Get-CWMScheduleEntry
        Will list all schedules entries.
        
        .NOTES
        Author: Chris Taylor
        Date: 10/10/2018
    
        .LINK
        http://labtechconsulting.com
        https://developer.connectwise.com/products/manage/rest?a=Schedule&e=ScheduleEntries&o=GET
        #>
        [CmdletBinding()]
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/schedule/entries"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
    function New-CWMScheduleEntry {
        <#
            .SYNOPSIS
            This function will create a new ticket.
        
            .EXAMPLE
            $Ticket = @{
                'identifier' = $Product.offerName
                'description' = $Product.offerName
                'subcategory' = @{id = 152}
                'type' = @{id = 47}
                'customerDescription' = $Product.offerName
                'cost' = $Product.unitPrice
                'price' = $Price
                'manufacturerPartNumber' = $Product.offerName
                'manufacturer' = $Manufacturer
                'productClass' = 'Agreement'
                'taxableFlag' = $true
            }
            New-CWMScheduleEntry @Ticket
            
            .NOTES
            Author: Chris Taylor
            Date: 8/22/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=Schedule&e=ScheduleEntries&o=CREATE    
        #>
        [CmdletBinding()]
        param(
            [int]$id,
            [int]$objectId,
            [ValidateLength(1,250)]
            [string]$name,
            [Parameter(Mandatory=$true)]
            $member,
            $where,
            [string]$dateStart,
            [string]$dateEnd,
            $reminder,
            $status,
            [Parameter(Mandatory=$true)]
            $type,
            $span,
            [boolean]$doneFlag,
            [boolean]$acknowledgedFlag,
            [boolean]$ownerFlag,
            [boolean]$meetingFlag,
            [boolean]$allowScheduleConflictsFlag,
            [boolean]$addMemberToProjectFlag,
            [int]$projectRoleId,
            [GUID]$mobileGuid,
            [string]$closeDate,
            [decimal]$hours,
            $_info
        )

        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/schedule/entries"
        return Invoke-CWMNewMaster -Arguments $PsBoundParameters -URI $URI          
    }
  #endregion [ScheduleEntries]-------
#endregion [Schedule]-------

#region [Service]-------
  #region [Tickets]-------
    function Get-CWMTicket {
        <#
            .SYNOPSIS
            This function list tickets that match your condition.
            
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results

            .EXAMPLE
            Get-CWMTicket -TicketID 1
            Returns ticket 1
            
            .EXAMPLE
            Get-CWMTicket -all
            Returns all tickets

            .EXAMPLE
            Get-CWMTicket -condition 'summary="test"'
            Returns the first 25 tickets with the summary of test

            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018

            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=Schedule&e=ScheduleEntries&o=GET
            https://developer.connectwise.com/products/manage/rest?a=Service&e=Tickets&o=GETBYID
        #>
        [CmdletBinding()]
        param(
            [int]$TicketID,
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
        if ($TicketID) {
            $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/service/tickets/$($TicketID)"        
            return Invoke-CWMGetMaster -URI $URI
        }
        else {
            if (($Condition.Length + $childconditions.Length + $customfieldconditions.Length) -gt 1000) {
                Write-Warning "Large conditions detected, consider using Find-CWMTicket."
            }
            $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/service/tickets"
            return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
        }
    }    
    function Find-CWMTicket {
        [CmdletBinding()]
        param(
            [string]$conditions,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [switch]$all
        )
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/service/tickets/search"
        return Invoke-CWMSearchMaster -Arguments $PsBoundParameters -URI $URI
    }
    function New-CWMTicket {
        <#
            .SYNOPSIS
            This function will create a new ticket.

            .EXAMPLE
            $Ticket = @{
                'identifier' = $Product.offerName
                'description' = $Product.offerName
                'subcategory' = @{id = 152}
                'type' = @{id = 47}
                'customerDescription' = $Product.offerName
                'cost' = $Product.unitPrice
                'price' = $Price
                'manufacturerPartNumber' = $Product.offerName
                'manufacturer' = $Manufacturer
                'productClass' = 'Agreement'
                'taxableFlag' = $true
            }
            New-CWMTicket @Ticket
    
            .NOTES
            Author: Chris Taylor
            Date: 8/22/2018

            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=Service&e=Tickets&o=CREATE    
        #>
        [CmdletBinding()]
        param(
            [int]$id,
            [Parameter(Mandatory=$true)]
            [ValidateLength(1,100)]
            [string]$summary,
            $recordType,
            $board,
            $status,
            $project,
            $phase,
            [ValidateLength(1,50)]
            [string]$wbsCode,
            [Parameter(Mandatory=$true)]
            $company,
            $site,
            [ValidateLength(1,50)]
            [string]$siteName,
            [ValidateLength(1,50)]
            [string]$addressLine1,
            [ValidateLength(1,50)]
            [string]$addressLine2,
            [ValidateLength(1,50)]
            [string]$city,
            [ValidateLength(1,50)]
            [string]$stateIdentifier,
            [ValidateLength(1,12)]
            [string]$zip,
            $country,
            $contact,
            [ValidateLength(1,62)]
            [string]$contactName,
            [ValidateLength(1,20)]
            [string]$contactPhoneNumber,
            [ValidateLength(1,15)]
            [string]$contactPhoneExtension,
            [ValidateLength(1,250)]
            [string]$contactEmailAddress,
            $type,
            $subType,
            $item,
            $team,
            $owner,
            $priority,
            $serviceLocation,
            $source,
            [string]$requiredDate,
            [decimal]$budgetHours,
            $opportunity,
            $agreement,
            [int]$severity,
            [int]$impact,
            [ValidateLength(1,100)]
            [string]$externalXRef,
            [ValidateLength(1,50)]
            [string]$poNumber,
            [int]$knowledgeBaseCategoryId,
            [int]$knowledgeBaseSubCategoryId,
            [boolean]$allowAllClientsPortalView,
            [boolean]$customerUpdatedFlag,
            [boolean]$automaticEmailContactFlag,
            [boolean]$automaticEmailResourceFlag,
            [boolean]$automaticEmailCcFlag,
            [ValidateLength(1,1000)]
            [string]$automaticEmailCc,
            [string]$initialDescription,
            [string]$initialInternalAnalysis,
            [string]$initialResolution,
            [string]$contactEmailLookup,
            [boolean]$processNotifications,
            [boolean]$skipCallback,
            [string]$closedDate,
            [string]$closedBy,
            [boolean]$closedFlag,
            [string]$dateEntered,
            [string]$enteredBy,
            [decimal]$actualHours,
            [boolean]$approved,
            $subBillingMethod,
            [decimal]$subBillingAmount,
            [string]$subDateAccepted,
            [string]$dateResolved,
            [string]$dateResplan,
            [string]$dateResponded,
            [int]$resolveMinutes,
            [int]$resPlanMinutes,
            [int]$respondMinutes,
            [boolean]$isInSla,
            [int]$knowledgeBaseLinkId,
            [string]$resources,
            [int]$parentTicketId,
            [boolean]$hasChildTicket,
            $knowledgeBaseLinkType,
            $billTime,
            $billExpenses,
            $billProducts,
            $predecessorType,
            [int]$predecessorId,
            [boolean]$predecessorClosedFlag,
            [int]$lagDays,
            [boolean]$lagNonworkingDaysFlag,
            [string]$estimatedStartDate,
            [int]$duration,
            [int]$locationId,
            [int]$businessUnitId,
            [guid]$mobileGuid,
            $sla,
            $currency,
            $_info,
            $customFields
        )
        
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/service/tickets"
        return Invoke-CWMNewMaster -Arguments $PsBoundParameters -URI $URI          
    }
    function Get-CWMTicketConfiguration {
       <#
           .SYNOPSIS
           This function will list configs attached to a ticket.
               
           .PARAMETER TicketID
           The id of the ticket you want to retreive configurations for.

           .PARAMETER orderBy
           Choose which field to sort the results by

           .PARAMETER childconditions
           Allows searching arrays on endpoints that list childConditions under parameters

           .PARAMETER customfieldconditions
           Allows searching custom fields when customFieldConditions is listed in the parameters

           .PARAMETER page
           Used in pagination to cycle through results

           .PARAMETER pageSize
           Number of results returned per page (Defaults to 25)

           .PARAMETER all
           Return all results

           .EXAMPLE
           Get-CWMTicketConfiguration -TicketID 1
           Will return all configurations for ticket 1
           
           .NOTES
           Author: Chris Taylor
           Date: 10/22/2018
           
           .LINK
           http://labtechconsulting.com
           https://developer.connectwise.com/products/manage/rest?a=Service&e=Tickets&o=CONFIGURATIONS  
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [int]$TicketID,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/service/tickets/$TicketID/configurations"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI            
    }
    function Update-CWMTicket {
        <#
            .SYNOPSIS
            This will update a ticket.
                
            .PARAMETER TicketID
            The ID of the ticket that you are updating.
    
            .PARAMETER Operation
            What you are doing with the value. 
            replace, add, remove
    
            .PARAMETER Path
            The value that you want to perform the operation on.
    
            .PARAMETER Value
            The value of path.
    
            .EXAMPLE
            $UpdateParam = @{
                ID = 1
                Operation = 'replace'
                Path = 'name'
                Value = $NewName
            }
            Update-CWMTicket @UpdateParam
           
            .NOTES
            Author: Chris Taylor
            Date: 10/22/2018
            
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=Service&e=Tickets&o=UPDATE
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [int]$TicketID,
            [Parameter(Mandatory=$true)]
            [validateset('add','replace','remove')]
            $Operation,
            [Parameter(Mandatory=$true)]
            [string]$Path,
            [Parameter(Mandatory=$true)]
            [string]$Value
        )
           
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/service/tickets/$TicketID"
        return Invoke-CWMUpdateMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [Tickets]-------
  #region [BoardStatuses]-------
    function Get-CWMBoardStatus {
        <#
            .SYNOPSIS
            This function will list the statuses of a service board based on conditions.
                
            .PARAMETER ServiceBoardID
            The ID of the service board you want to retrieve stateses for.

            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results

            .EXAMPLE
            Get-CWMBoardStatus -ServiceBoardID -Condition "status/id IN (1,42,43,57)" -all
            Will return all <SOMETHING> that match the condition

            .NOTES
            Author: Chris Taylor
            Date: 10/22/2018

            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=Service&e=BoardStatuses&o=GET  
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [int]$ServiceBoardID,
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )

        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/service/boards/$ServiceBoardID/statuses"

        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI            
    }
  #endregion [BoardStatuses]-------
  #region [BoardItems]-------
    function Get-CWMServiceBoard {
        <#
            .SYNOPSIS
            This function will list of service boards based on conditions.
                
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"
            
            .PARAMETER orderBy
            Choose which field to sort the results by
            
            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters
            
            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters
            
            .PARAMETER page
            Used in pagination to cycle through results
            
            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)
            
            .PARAMETER all
            Return all results
            
            .EXAMPLE
            Get-CWMServiceBoard -Condition "status/id IN (1,42,43,57)" -all
            Will return all service boards that match the condition
            
            .NOTES
            Author: Chris Taylor
            Date: 10/25/2018
            
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=Service&e=BoardInfos&o=BOARDS  
        #>
        [CmdletBinding()]
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/service/info/boards"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI            
    }
#endregion [BoardItems]-------
#endregion [Service]-------

#region [System]-------
  #region [Reports]-------
    function Get-CWMReport {
        <#
            .SYNOPSIS
            This function will allow you to search for Manage configurations.
        
            .PARAMETER Condition
            This is your search condition to return the results you desire.
            Example:
            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"

            .PARAMETER orderBy
            Choose which field to sort the results by

            .PARAMETER childconditions
            Allows searching arrays on endpoints that list childConditions under parameters

            .PARAMETER customfieldconditions
            Allows searching custom fields when customFieldConditions is listed in the parameters

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER all
            Return all results
        
            .EXAMPLE
            Get-CWMReport -Condition "name=`"$Report`""
            This will return all the reports with a name that matches $Report
        
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=System&e=Reports&o=GET
        #>
        [CmdletBinding()]
        param(
            [string]$Condition,
            [ValidateSet('asc','desc')] 
            $orderBy,
            [string]$childconditions,
            [string]$customfieldconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/system/reports"
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [Reports]-------
  #region [Documents]-------
    function Get-CWMDocument {
        <#
            .SYNOPSIS
            This function will list documents associated with a record.

            .PARAMETER RecordType
            The type of document you are looking for.
            Agreement, Company, Configuration, Contact, Expense, HTMLTemplate, Opportunity, Project, PurchaseOrder,
            Rma, SalesOrder, Ticket, ServiceTemplate, ToolbarIcon, Meeting, MeetingNote, ProductSetup, ProjectTemplateTicket,
            WordTemplate, Member, PhaseStatus, ProjectStatus, TicketStatus
        
            .PARAMETER RecordID
            The ID of a RecordType specified

            .PARAMETER page
            Used in pagination to cycle through results

            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)

            .PARAMETER pageID
            Used in pagination to request a page by id

            .EXAMPLE
            Find-CWMDocuments -RecordType Ticket -RecordID 1836414
            Will return documents associated with a the ticket 1936414
            
            .NOTES
            Author: Chris Taylor
            Date: 8/22/2018
        
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/manage/rest?a=System&e=Documents&o=GET
        #>
        [CmdletBinding()]
        param(
            [ValidateSet(
                'Agreement',
                'Company',
                'Configuration',
                'Contact',
                'Expense',
                'HTMLTemplate',
                'Opportunity',
                'Project',
                'PurchaseOrder',
                'Rma',
                'SalesOrder',
                'Ticket',
                'ServiceTemplate',
                'ToolbarIcon',
                'Meeting',
                'MeetingNote',
                'ProductSetup',
                'ProjectTemplateTicket',
                'WordTemplate',
                'Member',
                'PhaseStatus',
                'ProjectStatus',
                'TicketStatus'
            )]
            $RecordType,
            [int]$RecordID,
            [int]$page,
            [int]$pageSize,
            [int]$pageID
        )
    
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/system/documents"
        if ($RecordType) {$URI += "&recordType=$RecordType"}
        if ($RecordID) {$URI += "&recordId=$RecordID"}
    
        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI
    }
  #endregion [Documents]-------
  #region [AuditTrail]-------
    function Get-CWMAuditTrail {
        <#
            .SYNOPSIS
            This function will get the audit trail of an item in ConnectWise.

            .PARAMETER Type
            Ticket, ProductCatalog, Configuration, PurchaseOrder, Expense

            .PARAMETER ID
            The id the the item you want the audit trail of.

            .PARAMETER deviceIdentifier
            ?
                    
            .PARAMETER page
            Used in pagination to cycle through results
            
            .PARAMETER pageSize
            Number of results returned per page (Defaults to 25)
            
            .PARAMETER all
            Return all results
            
            .EXAMPLE
            Get-CWMAuditTrail
            Will return the audit trail
            
            .NOTES
            Author: Chris Taylor
            Date: 10/29/2018
            
            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=System&e=AuditTrail&o=GET 
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [validateset('Ticket', 'ProductCatalog', 'Configuration', 'PurchaseOrder', 'Expense')]
            $Type,
            [Parameter(Mandatory=$true)]
            [string]$ID,
            $deviceIdentifier,
            [string]$childconditions,
            [int]$page,
            [int]$pageSize,
            [switch]$all
        )
        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/system/audittrail"
        if($Type) {
            $URI += "?type=$type"
        }
        if($ID) {
            $URI += "&id=$ID"
        }
        if($deviceIdentifier) {
            $URI += "&deviceIdentifier=$deviceIdentifier"
        }

        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI            
    }
#endregion [AuditTrail]-------
    function Get-CWMChargeCode{
            <#
            .SYNOPSIS
            Gets a list of charge codes
            
            .EXAMPLE
            Get-ChargeCode
            
            .NOTES
            Author: Chris Taylor
            Date: 10/10/2018
        
            .LINK
            http://labtechconsulting.com
            #>
            [CmdletBinding()]
            param(
            )
        
            $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/system/reports/ChargeCode"    
            $Data = Invoke-CWMGetMaster -URI $URI
            return ConvertFrom-CWMColumnRow -Data $Data
        }
    function Get-CWMSystemInfo {
        <#
            .SYNOPSIS
            This function will return information about the connectwise server.

            .EXAMPLE
            Get-CWMSystemInfo
            Will return information about the connectwise server.

            .NOTES
            Author: Chris Taylor
            Date: 10/20/2018

            .LINK
            http://labtechconsulting.com
            https://developer.connectwise.com/products/manage/rest?a=System&e=Info&o=GET  
        #>
        [CmdletBinding()]
        param(
        )

        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/system/info"

        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI            
    }
#endregion [System]-------

#region [Time]-------
#endregion [Time]-------
#region [Templates]-------
#    function Get-CWMTemplate {
#        <#
#            .SYNOPSIS
#            This function will list <SOMETHING> based on conditions.
#                
#            .PARAMETER Condition
#            This is your search condition to return the results you desire.
#            Example:
#            (contact/name like "Fred%" and closedFlag = false) and dateEntered > [2015-12-23T05:53:27Z] or summary contains "test" AND  summary != "Some Summary"
#
#            .PARAMETER orderBy
#            Choose which field to sort the results by
#
#            .PARAMETER childconditions
#            Allows searching arrays on endpoints that list childConditions under parameters
#
#            .PARAMETER customfieldconditions
#            Allows searching custom fields when customFieldConditions is listed in the parameters
#
#            .PARAMETER page
#            Used in pagination to cycle through results
#
#            .PARAMETER pageSize
#            Number of results returned per page (Defaults to 25)
#
#            .PARAMETER all
#            Return all results
#
#            .EXAMPLE
#            Get-CWMTemplate -Condition "status/id IN (1,42,43,57)" -all
#            Will return all <SOMETHING> that match the condition
#
#            .NOTES
#            Author: Chris Taylor
#            Date: <GET-DATE>
#
#            .LINK
#            http://labtechconsulting.com
#            https://developer.connectwise.com/manage/rest?o=GET  
#        #>
#        [CmdletBinding()]
#        param(
#            [string]$Condition,
#            [ValidateSet('asc','desc')] 
#            $orderBy,
#            [string]$childconditions,
#            [string]$customfieldconditions,
#            [int]$page,
#            [int]$pageSize,
#            [switch]$all
#        )
#
#        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/<URI>"
#
#        return Invoke-CWMGetMaster -Arguments $PsBoundParameters -URI $URI            
#    }
#    function Update-CWMTemplate {
#        <#
#            .SYNOPSIS
#            This will update <SOMETHING>.
#                
#            .PARAMETER ID
#            The ID of the <SOMETHING> that you are updating.
#    
#            .PARAMETER Operation
#            What you are doing with the value. 
#            replace, add, remove
#    
#            .PARAMETER Path
#            The value that you want to perform the operation on.
#    
#            .PARAMETER Value
#            The value of path.
#    
#            .EXAMPLE
#            $UpdateParam = @{
#                ID = 1
#                Operation = 'replace'
#                Path = 'name'
#                Value = $NewName
#            }
#            Update-CWMTemplate @UpdateParam
#    
#            .NOTES
#            Author: Chris Taylor
#            Date: <GET-DATE>
#            
#            .LINK
#            http://labtechconsulting.com
#            https://service.itnow.net/v4_6_release/services/apitools/apidocumentation/rest?o=UPDATE
#        #>
#        [CmdletBinding()]
#        param(
#            [Parameter(Mandatory=$true)]
#            $ID,
#            [Parameter(Mandatory=$true)]
#            [validateset('add','replace','remove')]
#            $Operation,
#            [Parameter(Mandatory=$true)]
#            [string]$Path,
#            [Parameter(Mandatory=$true)]
#            [string]$Value
#        )
#    
#        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/<URI>/$ID"
#        return Invoke-CWMUpdateMaster -Arguments $PsBoundParameters -URI $URI
#    }
#    function New-CWMTemplate {
#        <#
#            .SYNOPSIS
#            This function will create a new <SOMETHING>.
#        
#            .EXAMPLE
#            New-CWMTemplate
#                Create a new <SOMETHING>.
#            
#            .NOTES
#            Author: Chris Taylor
#            Date: <GET-DATE>
#        
#            .LINK
#            http://labtechconsulting.com
#            https://developer.connectwise.com/manage/rest?o=CREATE    
#        #>
#        [CmdletBinding()]
#        param(
#        )
#            
#        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/<URI>"
#        return Invoke-CWMNewMaster -Arguments $PsBoundParameters -URI $URI
#    }
#    function Remove-CWMTemplate {
#        <#
#            .SYNOPSIS
#            This function will remove a <SOMETHING> from Manage.
#                
#            .PARAMETER ID
#            The ID of the <SOMETHING> you want to delete.
#
#            .EXAMPLE
#            Remove-CWMTemplate -ID 123
#
#            .NOTES
#            Author: Chris Taylor
#            Date: <GET-DATE>
#
#            .LINK
#            http://labtechconsulting.com
#            https://developer.connectwise.com/manage/rest?o=DELETE
#        #>
#        [CmdletBinding()]
#        param(
#            [int]$ID
#        )
#
#        $URI = "https://$($global:CWMServerConnection.Server)/v4_6_release/apis/3.0/<URI>/$ID"
#        return Invoke-CWMDeleteMaster -Arguments $PsBoundParameters -URI $URI            
#    }
# 
#endregion [Templates]-------
