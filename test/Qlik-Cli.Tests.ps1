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

                # TODO- Replace with clone and remove test
                $param =  @{ foo = "foo" }

                $result = DeepCopy $param

                $result.Count | Should Be $param.Count

                $param.foo | Should Be $result.foo

                $result.Add("bar","bar")
                
                $param.ContainsKey("bar") | Should Be $false

            }

            It "extracts custom properties" {

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
                Mock Get-QlikCustomProperty {}

                $param = @("Fruit=apple", "Color=green", "foo=bar")

                $result = GetCustomProperties $param

                Assert-VerifiableMocks

                $result.Count | Should Be 3
                $result[0].value | Should Be "apple"
                $result[0].definition | Should Be $customPropertiesMock[0]
                $result[1].value | Should Be "green"
                $result[1].definition | Should Be $customPropertiesMock[1]
                $result[2].value |Should Be $false
                $result[2].definition | Should Be $null
            }
        }
    }
}

Remove-Module Qlik-Cli
