#$here = Split-Path -Parent $MyInvocation.MyCommand.Path
#$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'. "$here\$sut"

Get-Module Qlik-Cli | Remove-Module -Force
Import-Module $PSScriptRoot\..\Qlik-Cli.psm1

InModuleScope Qlik-Cli {

    Describe "Testing GUID regex works correctly" {

        It "works with valid GUIDs" {

                "9ABCDeF9-9999-4444-4444-444444444444" -match $guid | Should be True
                "{9ABCDeF9-9999-4444-4444-444444444444" -match $guid | Should be True
                "{9ABCDeF9-9999-4444-4444-444444444444}" -match $guid | Should be True
                "9ABCDeF9-9999-4444-4444-444444444444}" -match $guid | Should be True
        }

        It "fails with invalid GUIDs" {
                "123fdBaX-fd45-fdFa-4323-fdCC4324323f" -match $guid | Should be False
                "123fdBa.-fd45-fdFa-4323-fdCC4324323f" -match $guid | Should be False

        }
    }
                    
    Describe "outputs a correct anti-forgery key" {

        $result = GetXrfKey

        It "is an arbitrary 16 char string" {

            $result | Should Match "^[a-z]{16}$"
        }
    }

    Describe "extracts custom properties" {

        # Refactor
        $customPropertiesMock = @(
            @{ id="00000000-0000-0000-0000-000000000000"
                name="Fruit"
                valueType = "Text"
                choiceValues = @("apple", "banana", "orange")
                privileges = $null
            },
            @{ id="00000000-0000-0000-0000-000000000001"
                name="Color"
                valueType = "Text"
                choiceValues = @("red", "green", "blue")
                privileges = $null
            }
        )

        Mock Get-QlikCustomProperty { $customPropertiesMock[0] } -Verifiable -ParameterFilter { $filter -eq "name eq 'Fruit'" }
        Mock Get-QlikCustomProperty { $customPropertiesMock[1] } -Verifiable -ParameterFilter { $filter -eq "name eq 'Color'" }
        Mock Get-QlikCustomProperty {} -Verifiable

        $param = @("Fruit=apple", "Color=green", "foo=bar")

        $result = GetCustomProperties $param

        Assert-VerifiableMocks

        It "returns the expected values when they exist" {

            $result.Count | Should Be 3
            $result[0].value | Should Be "apple"
            $result[0].definition | Should Be $customPropertiesMock[0]
            $result[1].value | Should Be "green"
            $result[1].definition | Should Be $customPropertiesMock[1]
        }

        It "returns a dummy object when the custom property does not exist" {

            $result[2].value |Should Be $false
            $result[2].definition | Should Be $null
        }
            
    }

    Describe "Testing how it extracts tags" {

        # Refactor
        $TagsMock = @(
            @{ id="00000000-0000-0000-0000-000000000000"
                name="Foo"
                privileges = $null
            },
            @{ id="00000000-0000-0000-0000-000000000001"
                name="Bar"
                privileges = $null
            }
        )

        Mock Get-QlikTag { $TagsMock[0] } -Verifiable -ParameterFilter { $filter -eq "name eq 'Foo'"}
        Mock Get-QlikTag { $TagsMock[1] } -Verifiable -ParameterFilter { $filter -eq "name eq 'Bar'"}
        Mock Get-QlikTag { } -Verifiable

        $result = GetTags @("Foo","Baz","Bar")

        Assert-VerifiableMocks

        It "returns the expected values when they exist" {

            $result.Count | Should Be 3
            $result[0].id | Should Be $TagsMock[0].id
            $result[2].id | Should Be $TagsMock[1].id

        }

        It "returns a NULL if the TAG does not exist" {
            $result[1].id | Should Be $null
        }
    }

    Describe "Testing calls to a REST Uri" {

        BeforeAll {

            $expectedMethod = "GET"
            $basePath = "foo/bar"
            $expectedPrefix = "prefix/"
            $expectedExtraParams = @{ Body = "some body content" }
            $fixedXrfKey = "abcdefghijklmno"
            $expectedPath = $expectedPrefix + $basePath + "?xrfkey=$fixedXrfKey"
            $expectedResult = @{ some = "result" }

            Set-Variable -Name "api_params" -Scope "script" -Value @{}

            Mock Connect-Qlik {} -Verifiable
            Mock GetXrfKey { $fixedXrfKey }
            Mock FormatOutput { $expectedResult }
            Mock Invoke-RestMethod { $expectedResult } -Verifiable
        }

        Context 'With $script:prefix prefix already defined' {

            BeforeAll {
                Set-Variable -Name "prefix" -Value $expectedPrefix -Scope "script"
            }

            AfterAll {
                Remove-Variable -Name "prefix" -Scope "script"
            }

            $result = CallRestUri $expectedMethod $basePath $expectedExtraParams
            
            It "Calls the expected Method" { 
                Assert-MockCalled Invoke-RestMethod -ParameterFilter { $method -eq $expectedMethod }
            }

            It "Calls the expected endpoint" {
                Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Uri -like $expectedPath }
            }

            It "doesn't tries to connect if prefix not null" {
                Assert-MockCalled Connect-Qlik -Times 0
            }

            It "Calls Invoke-RestMethod with added XrfKey Header param" {
                Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Headers."x-Qlik-Xrfkey" -eq $fixedXrfKey}
            }

            It "Sends the extra params" {
                Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Body -eq $expectedExtraParams.Body }
            }

            It "Returns the expected result" {
                $result | Should Be $expectedResult
            }

            It "webSession is captured if not defined" {
                Assert-MockCalled Invoke-RestMethod -ParameterFilter { $SessionVariable -eq "webSession" }
            }

            CallRestUri $expectedMethod "http://foo"

            It "Doesn't add prefix if path starts with http" {

                Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Uri -notlike "$expectedPrefix*" }
            }

            CallRestUri $expectedMethod "http://foo?bar=baz"

            It "adds XrfKey as Param" {
                Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Uri -eq "http://foo/?bar=baz&xrfkey=$fixedXrfkey"}
            }

        }

        Context 'With $script:prefix prefix not defined' {

            BeforeAll {
            #    Mock Connect-Qlik {} -Verifiable
            }

            CallRestUri $expectedMethod $basePath

            It "Calls Connect-Qlik" {
                Assert-MockCalled Connect-Qlik
            }
                    
        }

        Context 'With $script:webSession defined' {

            BeforeAll {
                $expectedWebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
                Set-Variable -Name "webSession" -Value $expectedWebSession -Scope "script"
            }

            AfterAll {
                Remove-Variable -Name "webSession" -Scope "script"
            }

            CallRestUri $expectedMethod $basePath

            It "reuses session variable" {

                Assert-MockCalled Invoke-RestMethod -ParameterFilter { $WebSession -eq $expectedWebSession }
            }
        }       
    }
}


Remove-Module Qlik-Cli
