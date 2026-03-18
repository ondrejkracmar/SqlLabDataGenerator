function Get-SldgScenarioTemplate {
	<#
	.SYNOPSIS
		Returns a built-in or auto-detected scenario template for domain-specific data generation.
	.DESCRIPTION
		Scenario templates provide industry-specific row count ratios and value rules
		that produce realistic relational data. When Name is 'Auto', the best-matching
		template is selected by analysing table names in the schema.

		Built-in scenarios: eCommerce, Healthcare, HR, Finance, Education.
	#>
	[CmdletBinding()]
	param (
		[string]$Name = 'Auto',

		$Schema
	)

	# Table role patterns are ordered from most-specific to least-specific.
	# Multipliers are relative to the base RowCount supplied to New-SldgGenerationPlan.
	$templates = @{
		'eCommerce' = @{
			Description = 'Online retail — customers, products, orders, reviews'
			TableRoles  = [ordered]@{
				'orderdetail|orderitem|orderline|lineitem|cartitem|basketitem' = @{ Role = 'Detail'; Multiplier = 8.0 }
				'order|purchase|sale|checkout'                                 = @{ Role = 'Transaction'; Multiplier = 3.0 }
				'review|rating|feedback|comment|testimonial'                   = @{ Role = 'Transaction'; Multiplier = 2.0 }
				'payment|invoice|billing|charge'                               = @{ Role = 'Transaction'; Multiplier = 3.0 }
				'address|shipping|delivery|shipment'                           = @{ Role = 'Detail'; Multiplier = 1.5 }
				'customer|client|user|account|member|shopper'                  = @{ Role = 'Master'; Multiplier = 1.0 }
				'product|item|sku|good|merchandise'                            = @{ Role = 'Reference'; Multiplier = 0.5 }
				'cart|basket|wishlist'                                         = @{ Role = 'Transaction'; Multiplier = 1.0 }
				'discount|coupon|promotion|voucher'                            = @{ Role = 'Lookup'; Multiplier = 0.1 }
				'category|type|tag|brand|manufacturer|supplier|vendor'         = @{ Role = 'Lookup'; Multiplier = 0.05 }
				'country|region|state|city|warehouse|store'                    = @{ Role = 'Lookup'; Multiplier = 0.03 }
			}
			ValueRules  = [ordered]@{
				'orderstatus|order_status'     = @('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled', 'Returned')
				'paymentstatus|payment_status'  = @('Pending', 'Completed', 'Failed', 'Refunded')
				'paymentmethod|payment_method'  = @('CreditCard', 'DebitCard', 'PayPal', 'BankTransfer', 'ApplePay')
				'currency|currencycode'         = @('USD', 'EUR', 'GBP', 'CAD', 'AUD')
				'status'                        = @('Active', 'Inactive', 'Pending', 'Suspended')
			}
		}

		'Healthcare' = @{
			Description = 'Medical facility — patients, visits, diagnoses, prescriptions'
			TableRoles  = [ordered]@{
				'diagnosis|condition|icd'                              = @{ Role = 'Detail'; Multiplier = 8.0 }
				'prescription|medication|drug|dosage'                  = @{ Role = 'Detail'; Multiplier = 6.0 }
				'labresult|testresult|lab_result|test_result'          = @{ Role = 'Detail'; Multiplier = 10.0 }
				'procedure|treatment|operation|surgery'                = @{ Role = 'Detail'; Multiplier = 3.0 }
				'visit|appointment|encounter|admission|consultation'   = @{ Role = 'Transaction'; Multiplier = 5.0 }
				'patient|person'                                       = @{ Role = 'Master'; Multiplier = 1.0 }
				'doctor|physician|provider|staff|nurse|practitioner'   = @{ Role = 'Reference'; Multiplier = 0.1 }
				'insurance|coverage|payer|plan'                        = @{ Role = 'Reference'; Multiplier = 0.2 }
				'department|ward|unit|specialty|clinic'                = @{ Role = 'Lookup'; Multiplier = 0.02 }
				'room|bed|facility|location'                           = @{ Role = 'Lookup'; Multiplier = 0.05 }
			}
			ValueRules  = [ordered]@{
				'gender|sex'                       = @('Male', 'Female', 'Other', 'Unknown')
				'bloodtype|blood_type'             = @('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')
				'priority|urgency|triage'          = @('Low', 'Normal', 'High', 'Urgent', 'Emergency')
				'visittype|visit_type|encountertype' = @('Outpatient', 'Inpatient', 'Emergency', 'Telehealth')
				'status'                           = @('Active', 'Inactive', 'Discharged', 'Deceased')
			}
		}

		'HR' = @{
			Description = 'Human resources — employees, departments, positions, payroll'
			TableRoles  = [ordered]@{
				'attendance|timesheet|clock|timelog'                   = @{ Role = 'Detail'; Multiplier = 20.0 }
				'leave|vacation|absence|timeoff|pto'                  = @{ Role = 'Transaction'; Multiplier = 5.0 }
				'salary|payroll|compensation|wage|bonus'              = @{ Role = 'Detail'; Multiplier = 3.0 }
				'performance|review|evaluation|appraisal'             = @{ Role = 'Transaction'; Multiplier = 2.0 }
				'employee|staff|worker|person|associate'              = @{ Role = 'Master'; Multiplier = 1.0 }
				'training|course|certification|skill'                 = @{ Role = 'Reference'; Multiplier = 0.3 }
				'benefit|insurance|plan|perks'                        = @{ Role = 'Reference'; Multiplier = 0.2 }
				'department|division|team|group|unit'                 = @{ Role = 'Lookup'; Multiplier = 0.05 }
				'position|jobtitle|role|grade|level'                  = @{ Role = 'Lookup'; Multiplier = 0.1 }
				'office|location|branch|site'                         = @{ Role = 'Lookup'; Multiplier = 0.03 }
			}
			ValueRules  = [ordered]@{
				'employmenttype|employment_type'           = @('FullTime', 'PartTime', 'Contract', 'Intern', 'Temporary')
				'leavetype|leave_type|absencetype'         = @('Annual', 'Sick', 'Personal', 'Maternity', 'Paternity', 'Unpaid')
				'performancerating|performance_rating'     = @('Exceptional', 'Exceeds', 'Meets', 'Below', 'Unsatisfactory')
				'status'                                   = @('Active', 'OnLeave', 'Terminated', 'Retired')
			}
		}

		'Finance' = @{
			Description = 'Financial services — accounts, transactions, reporting'
			TableRoles  = [ordered]@{
				'auditlog|audit_log|history|changelog'                 = @{ Role = 'Detail'; Multiplier = 30.0 }
				'transaction|transfer|payment|movement'               = @{ Role = 'Transaction'; Multiplier = 20.0 }
				'balance|ledger|journal|entry|posting'                 = @{ Role = 'Detail'; Multiplier = 10.0 }
				'account|customer|client|holder'                      = @{ Role = 'Master'; Multiplier = 1.0 }
				'loan|mortgage|credit|facility'                       = @{ Role = 'Detail'; Multiplier = 0.5 }
				'branch|office|location'                              = @{ Role = 'Reference'; Multiplier = 0.05 }
				'accounttype|account_type|category|code|lookup'       = @{ Role = 'Lookup'; Multiplier = 0.02 }
				'currency|exchangerate|exchange_rate'                  = @{ Role = 'Lookup'; Multiplier = 0.01 }
			}
			ValueRules  = [ordered]@{
				'transactiontype|transaction_type|txntype' = @('Deposit', 'Withdrawal', 'Transfer', 'Fee', 'Interest', 'Refund')
				'accounttype|account_type'                 = @('Savings', 'Checking', 'Business', 'Investment', 'Retirement')
				'currency|currencycode'                    = @('USD', 'EUR', 'GBP', 'CHF', 'JPY')
				'status'                                   = @('Active', 'Closed', 'Frozen', 'Pending')
			}
		}

		'Education' = @{
			Description = 'Educational institution — students, courses, enrollment'
			TableRoles  = [ordered]@{
				'attendance|presence|absence'                           = @{ Role = 'Detail'; Multiplier = 30.0 }
				'grade|score|result|mark|assessment'                    = @{ Role = 'Detail'; Multiplier = 12.0 }
				'assignment|homework|exam|test|quiz'                    = @{ Role = 'Detail'; Multiplier = 8.0 }
				'enrollment|registration|enrolment'                     = @{ Role = 'Transaction'; Multiplier = 4.0 }
				'student|learner|pupil'                                 = @{ Role = 'Master'; Multiplier = 1.0 }
				'course|class|subject|module|curriculum'                = @{ Role = 'Reference'; Multiplier = 0.3 }
				'teacher|instructor|professor|faculty|lecturer'         = @{ Role = 'Reference'; Multiplier = 0.1 }
				'department|school|faculty|institute'                   = @{ Role = 'Lookup'; Multiplier = 0.03 }
				'semester|term|period|academicyear|academic_year'       = @{ Role = 'Lookup'; Multiplier = 0.01 }
				'classroom|room|building|campus'                        = @{ Role = 'Lookup'; Multiplier = 0.02 }
			}
			ValueRules  = [ordered]@{
				'enrollmentstatus|enrollment_status'  = @('Enrolled', 'Waitlisted', 'Dropped', 'Completed')
				'lettergrade|letter_grade'            = @('A', 'B', 'C', 'D', 'F')
				'semester|term'                       = @('Fall', 'Spring', 'Summer')
				'status'                              = @('Active', 'Graduated', 'Withdrawn', 'Suspended', 'OnLeave')
			}
		}
	}

	# Auto-detect: match schema table names against all scenario patterns
	if ($Name -eq 'Auto' -and $Schema) {
		$bestMatch = $null
		$bestScore = 0

		foreach ($scenarioName in $templates.Keys) {
			$scenario = $templates[$scenarioName]
			$matchCount = 0

			foreach ($table in $Schema.Tables) {
				$tableLower = $table.TableName.ToLower()
				foreach ($pattern in $scenario.TableRoles.Keys) {
					if ($tableLower -match $pattern) {
						$matchCount++
						break
					}
				}
			}

			if ($matchCount -gt $bestScore) {
				$bestScore = $matchCount
				$bestMatch = $scenarioName
			}
		}

		if ($bestMatch -and $bestScore -ge 3) {
			$Name = $bestMatch
			Write-PSFMessage -Level Host -Message ($script:strings.'Scenario.AutoDetected' -f $bestMatch, $bestScore)
		}
		else {
			Write-PSFMessage -Level Verbose -Message "No scenario template matched the schema (best score: $bestScore). Returning null."
			return $null
		}
	}

	if (-not $templates.ContainsKey($Name)) {
		$available = $templates.Keys -join ', '
		Write-PSFMessage -Level Warning -Message ($script:strings.'Scenario.NotFound' -f $Name, $available)
		return $null
	}

	$template = $templates[$Name]
	[PSCustomObject]@{
		PSTypeName  = 'SqlLabDataGenerator.ScenarioTemplate'
		Name        = $Name
		Description = $template.Description
		TableRoles  = $template.TableRoles
		ValueRules  = $template.ValueRules
	}
}
