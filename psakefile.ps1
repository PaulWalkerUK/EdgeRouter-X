task default -depends Build

task Clean {
    Remove-Item PSEdgeRouterX.psd1 -ErrorAction SilentlyContinue
}

task Build -depends Clean {
    $version = GitVersion.exe|ConvertFrom-Json

    $params = @{
        Path = 'PSEdgeRouterX.psd1'

        RootModule = 'PSEdgeRouterX.psm1'
        
        ModuleVersion = $version.MajorMinorPatch
        
        Author = 'Paul Walker'

        CompanyName = 'N/A'
        
        Copyright = '(c) 2018 Paul Walker. All rights reserved.'
        
        Description = 'To assist in configuring the Ubiquiti EdgeRouter X.
This is in no way affiliated with or supported by Ubiquiti.'
        
        FunctionsToExport = @(
            'Get-Firewall'
        )

        PrivateData = @{
            FullSemVer = $version.FullSemVer
            InformationalVersion = $version.InformationalVersion
        }
    }
    
    New-ModuleManifest @params
}