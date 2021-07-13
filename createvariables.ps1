
$OpenWith = @{}
$OpenWith.Add('MSI_ID', $MSI_ID)
Set-AzWebApp -AppSettings $OpenWith> -Name 'ContosoWebApp' -ResourceGroupName 'Default-Web-WestUS'