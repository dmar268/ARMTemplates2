param (
    [string]$resourceGroup,
    [string]$existingRg,
    [array]$storageAccounts
)
Get-AzureRmResourceGroup -Name $resourceGroup -ErrorAction SilentlyContinue -ErrorVariable rgError

if ($rgError) {
	
	$storageAccounts | % {
	
		$accessKey = (Get-AzureRmStorageAccountKey -StorageAccountName $_ -ResourceGroupName $existingRg).Value[0]
		$Storage = New-AzureStorageContext -StorageAccountName $_ -StorageAccountKey $accessKey
	
		Get-AzureStorageContainer -Context $Storage -Container $resourceGroup -ErrorAction SilentlyContinue -ErrorVariable blobError
	
		if (!$blobError) {
	
			Remove-AzureStorageContainer -Context $Storage -Container $resourceGroup -Confirm:$false -Force -ErrorAction SilentlyContinue
	
		}
	
	}

}
