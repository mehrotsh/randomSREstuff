$tenantId = "your-tenant-id"
$clientId = "your-client-id"
$clientSecret = ConvertTo-SecureString "your-client-secret" -AsPlainText -Force

$creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $clientId, $clientSecret

Connect-AzAccount -ServicePrincipal -Credential $creds -Tenant $tenantId
$runbookName = "YourRunbookName"

Register-AzAutomationScheduledRunbook -ResourceGroupName $resourceGroupName `
    -AutomationAccountName $automationAccountName `
    -RunbookName $runbookName `
    -ScheduleName $scheduleName
