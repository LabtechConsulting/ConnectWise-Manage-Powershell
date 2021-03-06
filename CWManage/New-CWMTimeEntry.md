# New-CWMTimeEntry
## SYNOPSIS
This function will create a new time entry.
## SYNTAX
```powershell
New-CWMTimeEntry [-id <Int32>] -company <Object> [-member <Object>] [-locationId <Int32>] [-businessUnitId <Int32>] [-workType <Object>] [-workRole <Object>] [-agreement <Object>] [-timeStart <String>] [-timeEnd <String>] [-hoursDeduct <Double>] [-actualHours <Double>] [-billableOption <Object>] [-notes <String>] [-internalNotes <String>] [-addToDetailDescriptionFlag <Boolean>] [-addToInternalAnalysisFlag <Boolean>] [-addToResolutionFlag <Boolean>] [-emailResourceFlag <Boolean>] 

[-emailContactFlag <Boolean>] [-emailCcFlag <Boolean>] [-emailCc <String>] [-hoursBilled <Double>] [-enteredBy <String>] [-dateEntered <String>] [-invoice <Object>] [-mobileGuid <Guid>] [-hourlyRate <Double>] [-timeSheet <Object>] [-status <Object>] [-_info <Object>] [-customFields <Object>] [<CommonParameters>]



New-CWMTimeEntry [-id <Int32>] -chargeToId <Int32> -chargeToType <Object> [-member <Object>] [-locationId <Int32>] [-businessUnitId <Int32>] [-workType <Object>] [-workRole <Object>] [-agreement <Object>] [-timeStart <String>] [-timeEnd <String>] [-hoursDeduct <Double>] [-actualHours <Double>] [-billableOption <Object>] [-notes <String>] [-internalNotes <String>] [-addToDetailDescriptionFlag <Boolean>] [-addToInternalAnalysisFlag <Boolean>] [-addToResolutionFlag <Boolean>] [-emailResourceFlag 

<Boolean>] [-emailContactFlag <Boolean>] [-emailCcFlag <Boolean>] [-emailCc <String>] [-hoursBilled <Double>] [-enteredBy <String>] [-dateEntered <String>] [-invoice <Object>] [-mobileGuid <Guid>] [-hourlyRate <Double>] [-timeSheet <Object>] [-status <Object>] [-_info <Object>] [-customFields <Object>] [<CommonParameters>]
```
## PARAMETERS
### -id &lt;Int32&gt;

```
Required                    false
Position                    named
Default value                0
Accept pipeline input       false
Accept wildcard characters  false
```
### -company &lt;Object&gt;

```
Required                    true
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -chargeToId &lt;Int32&gt;

```
Required                    true
Position                    named
Default value                0
Accept pipeline input       false
Accept wildcard characters  false
```
### -chargeToType &lt;Object&gt;

```
Required                    true
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -member &lt;Object&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -locationId &lt;Int32&gt;

```
Required                    false
Position                    named
Default value                0
Accept pipeline input       false
Accept wildcard characters  false
```
### -businessUnitId &lt;Int32&gt;

```
Required                    false
Position                    named
Default value                0
Accept pipeline input       false
Accept wildcard characters  false
```
### -workType &lt;Object&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -workRole &lt;Object&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -agreement &lt;Object&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -timeStart &lt;String&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -timeEnd &lt;String&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -hoursDeduct &lt;Double&gt;

```
Required                    false
Position                    named
Default value                0
Accept pipeline input       false
Accept wildcard characters  false
```
### -actualHours &lt;Double&gt;

```
Required                    false
Position                    named
Default value                0
Accept pipeline input       false
Accept wildcard characters  false
```
### -billableOption &lt;Object&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -notes &lt;String&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -internalNotes &lt;String&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -addToDetailDescriptionFlag &lt;Boolean&gt;

```
Required                    false
Position                    named
Default value                False
Accept pipeline input       false
Accept wildcard characters  false
```
### -addToInternalAnalysisFlag &lt;Boolean&gt;

```
Required                    false
Position                    named
Default value                False
Accept pipeline input       false
Accept wildcard characters  false
```
### -addToResolutionFlag &lt;Boolean&gt;

```
Required                    false
Position                    named
Default value                False
Accept pipeline input       false
Accept wildcard characters  false
```
### -emailResourceFlag &lt;Boolean&gt;

```
Required                    false
Position                    named
Default value                False
Accept pipeline input       false
Accept wildcard characters  false
```
### -emailContactFlag &lt;Boolean&gt;

```
Required                    false
Position                    named
Default value                False
Accept pipeline input       false
Accept wildcard characters  false
```
### -emailCcFlag &lt;Boolean&gt;

```
Required                    false
Position                    named
Default value                False
Accept pipeline input       false
Accept wildcard characters  false
```
### -emailCc &lt;String&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -hoursBilled &lt;Double&gt;

```
Required                    false
Position                    named
Default value                0
Accept pipeline input       false
Accept wildcard characters  false
```
### -enteredBy &lt;String&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -dateEntered &lt;String&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -invoice &lt;Object&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -mobileGuid &lt;Guid&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -hourlyRate &lt;Double&gt;

```
Required                    false
Position                    named
Default value                0
Accept pipeline input       false
Accept wildcard characters  false
```
### -timeSheet &lt;Object&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -status &lt;Object&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -_info &lt;Object&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
### -customFields &lt;Object&gt;

```
Required                    false
Position                    named
Default value
Accept pipeline input       false
Accept wildcard characters  false
```
## EXAMPLES
### EXAMPLE 1
```powershell
PS C:\>New-CWMTimeEntry

Create a new <SOMETHING>.
```

## NOTES
Author: Chris Taylor

Date: 1/7/2019 
## LINKS
http://labtechconsulting.com

https://developer.connectwise.com/manage/rest?a=Time&e=TimeEntries&o=CREATE
