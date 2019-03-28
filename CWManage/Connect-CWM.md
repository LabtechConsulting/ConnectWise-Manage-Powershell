# Connect-CWM
## SYNOPSIS
This will initialize the authorization variable.
## SYNTAX
```powershell
Connect-CWM [-Server] <String> [-Company] <String> [[-pubkey] <String>] [[-privatekey] <String>] [[-Credentials] <PSCredential>] [[-IntegratorUser] <String>] [[-IntegratorPass] <String>] [[-MemberID] <String>] [-Force] [-DontWarn] [<CommonParameters>] [[-ClientID] <String>]
```
## DESCRIPTION
This will create a global variable that contains all needed connection and authorization information.
All other commands from the module will call this variable to get connection information.
## PARAMETERS
### -Server &lt;String&gt;
The URL of your ConnectWise Mange server.

Example: manage.mydomain.com
```
Required                    true
Position                    1
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -Company &lt;String&gt;
The login company.
```
Required                    true
Position                    2
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -pubkey &lt;String&gt;
Public API key created by a user

docs: My Account
```
Required                    false
Position                    3
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -privatekey &lt;String&gt;
Private API key created by a user

docs: My Account
```
Required                    false
Position                    4
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -Credentials &lt;PSCredential&gt;
Manage username and password as a PSCredential object [pscredential].
```
Required                    false
Position                    5
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -IntegratorUser &lt;String&gt;
The integrator username

docs: Member Impersonation
```
Required                    false
Position                    6
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -IntegratorPass &lt;String&gt;
The integrator password

docs: Member Impersonation
```
Required                    false
Position                    7
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -MemberID &lt;String&gt;
The member that you are impersonating
```
Required                    false
Position                    8
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -Force &lt;SwitchParameter&gt;
Ignore cached information and recreate
```
Required                    false
Position                    named
Default value                False
Accept pipeline input       false
Accept wildcard characters  false
```
### -DontWarn &lt;SwitchParameter&gt;
Used to suppress the warning about integrator accounts.
```
Required                    false
Position                    named
Default value                False
Accept pipeline input       false
Accept wildcard characters  false
```
### -ClientID &lt;String&gt;
Used to pass newly required ClientID for Manage 2019.3.
```
Required                    false
Position                    named
Default value                False
Accept pipeline input       false
Accept wildcard characters  false
```

## EXAMPLES
### EXAMPLE 1
```powershell
PS C:\>$Connection = @{

Server = $Server
    Company = $Company 
    pubkey = $pubkey
    privatekey = $privatekey
}
Connect-CWM @Connection
```

### EXAMPLE 2
```powershell
PS C:\>$Connection = @{

Server = $Server
    Company = $Company 
    IntegratorUser = $IntegratorUser
    IntegratorPass = $IntegratorPass
}
Connect-CWM @Connection
```

### EXAMPLE 3
```powershell
PS C:\>$Connection = @{

Server = $Server
    Company = $Company 
    IntegratorUser = $IntegratorUser
    IntegratorPass = $IntegratorPass
    MemberID = $MemberID
}
Connect-CWM @Connection
```

### EXAMPLE 4
```powershell
PS C:\>$Connection = @{

Server = $Server
    Company = $Company 
    Credentials = $Credentials
}
Connect-CWM @Connection
```

## NOTES
Author: Chris Taylor

Date: 10/10/2018 
## LINKS
http://labtechconsulting.com

https://developer.connectwise.com/Manage/Developer_Guide#Authentication
