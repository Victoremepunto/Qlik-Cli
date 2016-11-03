#$here = Split-Path -Parent $MyInvocation.MyCommand.Path
#$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'. "$here\$sut"

Get-Module Qlik-Cli | Remove-Module -Force
Import-Module $PSScriptRoot\..\Qlik-Cli.psm1

InModuleScope Qlik-Cli {

    Describe "Testing Qlik-Cli" {

        Context "Internal Functions" {

            It "GUID regex works correctly" {

                "9ABCDeF9-9999-4444-4444-444444444444" -match $guid | Should be True
                "{9ABCDeF9-9999-4444-4444-444444444444" -match $guid | Should be True
                "{9ABCDeF9-9999-4444-4444-444444444444}" -match $guid | Should be True
                "9ABCDeF9-9999-4444-4444-444444444444}" -match $guid | Should be True

                "123fdBaX-fd45-fdFa-4323-fdCC4324323f" -match $guid | Should be False
                "123fdBa.-fd45-fdFa-4323-fdCC4324323f" -match $guid | Should be False
            }
        
            $result = GetXrfKey

            It "outputs a correct anti-forgery key" {

                $result | Should Match "^[a-z]{16}$"
            }

            It "DeepCopy 'deepcopies' the input to the output" {
                
                $param =  @{ foo = "foo" }

                $result = DeepCopy $param

                $result.Count | Should Be $param.Count

                $param.foo | Should Be $result.foo

                $result.Add("bar","bar")
                
                $param.ContainsKey("bar") | Should Be $false

                
                #$result | Should Be @{ foo = "foo" ; bar = "bar"}
                #$result | Should Be @{bar = "bar" ; foo = "foo"}

                #$result.Count | Should Be $param.Count 

                #foreach ($key in $result.Keys) {
                #    $result.$key | Should Be $param.$key 
                #}

            }
        }
    }
}

Remove-Module Qlik-Cli