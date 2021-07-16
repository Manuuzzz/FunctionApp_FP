# Input bindings are passed in via param block.
param($Timer)
#Todo: rotate keys

import-Module Az.Storage

function Search-Log {

    param(
        [parameter(Mandatory=$false)]
        [string] $startDate,
         
        [string] $endDate,
        
        [int] $nbrOfDays
        
        )
        
       

        # to use in function app via app settings: $ENV:StorageAccount
        $StorageAccountName = $env:StorageAccountName
           
        
        $ContainerName = "powerbilogs"
        $ArchiveContainerName = "powerbiarchivelogs"
        $BlobPath = "local/"
        $BlobArchivePath = "local/archivePowerBIAudit/"
    
        $FileName = "PowerBIAudit" 
        #$TempDir = $Env:temp + "/"
        
        #$TempFileName = $TempDir  + $FileName + ".csv"
        $TempFileName = $FileName + ".csv"
        $BlobFileName = $BlobPath + $FileName + ".csv"
        
        if (-not $startDate){
            $startDate=(get-date).AddDays(-$nbrOfDays).ToString("yyyy-MM-dd")
        }
        
        if (-not $endDate){
            $endDate=(get-date).ToString("yyyy-MM-dd")
        }
        
        Write-Output "startDate: " $startDate
        Write-Output "endDate: " $endDate
        
        $scriptStart=(get-date)
        
        $datestring = $startDate.Replace('-','') + '_' + $endDate.Replace('-','')
        $ArchiveBlobFileName = $BlobArchivePath + $FileName + "_" + $datestring + ".csv"
        
        $sessionName = (get-date -Format 'u')+'pbiauditlog'
        
                
        $user_SecureFromKV = Get-AzKeyVaultSecret -VaultName "awe-in-kv-bi-02" -Name "exchangeonlineuser"
        #Convert the secure username from the keyvault to plain text, so we can pass it in the credential object
        $User = $user_SecureFromKV.SecretValue | ConvertFrom-SecureString -AsPlainText  
        $PWord = Get-AzKeyVaultSecret -VaultName "awe-in-kv-bi-02" -Name "exchangeonlinepassword"
        # Check the value with following command, this only works from Powershell 7 and up.
        #$password.SecretValue | ConvertFrom-SecureString -AsPlainText  
        
        #Create the credential from the keyvault username and password
        $UserCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord.SecretValue
        Connect-ExchangeOnline -Credential $UserCredential -ShowBanner:$false -ExchangeEnvironmentName O365Default 
        



        
        # Reset user audit accumulator
        $aggregateResults = @()
        $i = 0 # Loop counter
        Do { 
            $currentResults = Search-UnifiedAuditLog -StartDate $startDate -EndDate $enddate `
                                        -SessionId $sessionName -SessionCommand ReturnLargeSet  -ResultSize 5000 -RecordType PowerBIAudit
            if ($currentResults.Count -gt 0) {
                Write-Output ("  Finished {3} search #{1}, {2} records: {0} min" -f [math]::Round((New-TimeSpan -Start $scriptStart).TotalMinutes,4), $i, $currentResults.Count, $user.UserPrincipalName )
                # Accumulate the data
                $aggregateResults += $currentResults
                # No need to do another query if the # recs returned <1k - should save around 5-10 sec per user
                if ($currentResults.Count -lt 1000) {
                    $currentResults = @()
                } else {
                    $i++
                }
            }
        } Until ($currentResults.Count -eq 0) # --- End of Session Search Loop --- #
        
        $data=@()
        foreach ($auditlogitem in $aggregateResults) {
            $datum = New-Object –TypeName PSObject
            $d=convertfrom-json $auditlogitem.AuditData
            $datum | Add-Member –MemberType NoteProperty –Name Id –Value $d.Id
            $datum | Add-Member –MemberType NoteProperty –Name CreationTime –Value $auditlogitem.CreationDate    
            $datum | Add-Member –MemberType NoteProperty –Name RecordTypeCode –Value $d.RecordType
            $datum | Add-Member –MemberType NoteProperty –Name RecordTypeName –Value $auditlogitem.RecordType
            $datum | Add-Member –MemberType NoteProperty –Name Workload –Value $d.Workload
            $datum | Add-Member –MemberType NoteProperty –Name Operation –Value $d.Operation
            $datum | Add-Member –MemberType NoteProperty –Name UserType –Value $d.UserType
            $datum | Add-Member –MemberType NoteProperty –Name UserKey –Value $d.UserKey    
            $datum | Add-Member –MemberType NoteProperty –Name UserId –Value $d.UserId
            $datum | Add-Member –MemberType NoteProperty –Name UserAgent –Value $d.UserAgent
            $datum | Add-Member –MemberType NoteProperty –Name RequestId –Value $d.RequestId
            $datum | Add-Member –MemberType NoteProperty –Name ActivityId –Value $d.ActivityId
            $datum | Add-Member –MemberType NoteProperty –Name Activity –Value $d.Activity
            $datum | Add-Member –MemberType NoteProperty –Name ItemName –Value $d.ItemName
            $datum | Add-Member –MemberType NoteProperty –Name WorkspaceId –Value $d.WorkspaceId
            $datum | Add-Member –MemberType NoteProperty –Name WorkSpaceName –Value $d.WorkSpaceName
            $datum | Add-Member –MemberType NoteProperty –Name DashboardId –Value $d.DashboardId
            $datum | Add-Member –MemberType NoteProperty –Name DashboardName –Value $d.DashboardName
            $datum | Add-Member –MemberType NoteProperty –Name DatasetId –Value $d.DatasetId
            $datum | Add-Member –MemberType NoteProperty –Name DatasetName –Value $d.DatasetName
            $datum | Add-Member –MemberType NoteProperty –Name ReportId –Value $d.ReportId
            $datum | Add-Member –MemberType NoteProperty –Name ReportName –Value $d.ReportName    
            $datum | Add-Member –MemberType NoteProperty –Name IsSuccess –Value $d.IsSuccess
            $data+=$datum
        }
        
        Write-Output (" writing to file {0}" -f $TempFileName)
        $data | Export-csv -Path $TempFileName -Delimiter ';' -NoTypeInformation
        Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue
        
		#$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
        $ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount
       
        Write-Output (" uploading file {0} to blob storage" -f $TempFileName)
        Set-AzStorageBlobContent -File $TempFileName -Container $ContainerName -Blob $BlobFileName -Force -Context $ctx
        Set-AzStorageBlobContent -File $TempFileName -Container $ArchiveContainerName -Blob $ArchiveBlobFileName -Force -Context $ctx
        
      
    
    }
#Search-Log -nbrOfDays 10
Search-Log -nbrOfDays 1


