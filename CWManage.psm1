function Connect-ConnectWiseManage {
    param(
        [Parameter(Mandatory=$true)]
        $Server,
        [Parameter(Mandatory=$true)]
        $Company,
        $MemberID,
        $IntegratorUser,
        $IntegratorPass,        
        $pubkey,
        $privatekey
    )

    # If connecting with a public/private API key
    if($pubkey -and $privatekey){
        $Authstring  = $Company + '+' + $pubkey + ':' + $privatekey
        $encodedAuth  = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(($Authstring)));
        $Headers=@{
            Authorization = "Basic $encodedAuth"
            'Cache-Control'= 'no-cache'
        }             
    }

    # If connecting with an integrator account and memberid
    if($IntegratorUser -and $IntegratorPass){
        $URL = "https://$($Server)/v4_6_release/apis/3.0/system/members/$($MemberID)/tokens"
        # Create auth header to get auth header ;P
        $Authstring  = $Company + '+' + $IntegratorUser + ':' + $IntegratorPass
        $encodedAuth  = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(($Authstring)));
        $Headers = @{
            Authorization = "Basic $encodedAuth"
            'x-cw-usertype' ="integrator"
            'Cache-Control'= 'no-cache'
        }
        $Body = @{
            memberIdentifier = $MemberID
        }
    
        # Get an auth token
        $Result = Invoke-RestMethod -Method Post -Uri $URL -Headers $Headers -Body $Body -ContentType application/json

        # Create auth header
        $Authstring  = $Company + '+' + $Result.publicKey + ':' + $Result.privateKey
        $encodedAuth  = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(($Authstring)));
        $Headers=@{
            Authorization = "Basic $encodedAuth"
           'Cache-Control'= 'no-cache'
        }    
    }

    # Creat the Server Connection object    
    $global:CWServerConnection = @{
        Server = $Server
        Headers = $Headers
    }
    
}
function Get-CWConfig {
    param(
        $Condition        
    )
    if(!$global:CWServerConnection){
        Write-Error "Not connected to a Manage server. Run Connect-ConnectWiseManage first."
        break
    }

    $URI = "https://$($global:CWServerConnection.Server)/v4_6_release/apis/3.0/company/configurations"
    if($Condition){$URI += "?conditions=$Condition"}
    
    $Config = Invoke-RestMethod -Headers $global:CWServerConnection.Headers -Uri $URI -Method GET
    return $Config
}
function Get-CWAgreement {
    param(
        $Condition
    )
    if(!$global:CWServerConnection){
        Write-Error "Not connected to a Manage server. Run Connect-ConnectWiseManage first."
        break
    }

    $URI = "https://$($global:CWServerConnection.Server)/v4_6_release/apis/3.0/finance/agreements"
    if($Condition){
        $URI += "?conditions=$Condition"
    }

    $Agreement = Invoke-RestMethod -Headers $global:CWServerConnection.Headers -Uri $URI -Method GET
    return $Agreement
}
function Get-CWAddition {
    param(
        $AgreementID
    )
    if(!$global:CWServerConnection){
        Write-Error "Not connected to a Manage server. Run Connect-ConnectWiseManage first."
        break
    }

    $URI = "https://$($global:CWServerConnection.Server)/v4_6_release/apis/3.0/finance/agreements/$AgreementID/additions"
    
    $Addition = Invoke-RestMethod -Headers $global:CWServerConnection.Headers -Uri $URI -Method GET
    return $Addition
}
function Get-ChargeCode{
    param(
    )
    if(!$global:CWServerConnection){
        Write-Error "Not connected to a Manage server. Run Connect-ConnectWiseManage first."
        break
    }

    $URI = "https://$($global:CWServerConnection.Server)/v4_6_release/apis/3.0/system/reports/ChargeCode"
    
    $ChargeCode = Invoke-RestMethod -Headers $global:CWServerConnection.Headers -Uri $URI -Method GET
    
    # Clean the returned object up
    $Item = @{}
    For ($a=0; $a -lt $ChargeCode.row_values.count; $a++){
        For ($b=0; $b -lt $ChargeCode.column_definitions.count; $b++){
            $Property += @{$(($ChargeCode.column_definitions[$b] | Get-Member -MemberType NoteProperty).Name) = $($ChargeCode.row_values[$a][$b])}
        }
        $Item.add($Property.Description,$Property)
        Remove-Variable Property -ErrorAction SilentlyContinue
    }
    return $Item

}
