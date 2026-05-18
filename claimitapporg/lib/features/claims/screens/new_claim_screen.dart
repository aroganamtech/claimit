import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/claims_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/loading_button.dart';

class NewClaimScreen extends StatefulWidget {
  const NewClaimScreen({super.key});

  @override
  State<NewClaimScreen> createState() => _NewClaimScreenState();
}

class _NewClaimScreenState extends State<NewClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  final _policyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();

  String? _selectedClaimType;
  DateTime? _incidentDate;
  int _currentStep = 0;

  @override
  void dispose() {
    _policyController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.secondaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _incidentDate = date;
        _dateController.text = DateFormat('dd MMM yyyy').format(date);
      });
    }
  }

  Future<void> _submitClaim() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClaimType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a claim type'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    if (_incidentDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the incident date'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final provider = context.read<ClaimsProvider>();
    final claim = await provider.createClaim(
      claimType: _selectedClaimType!,
      policyNumber: _policyController.text.trim(),
      description: _descriptionController.text.trim(),
      claimAmount: double.parse(_amountController.text.trim()),
      incidentDate: _incidentDate!,
    );

    if (!mounted) return;

    if (claim != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Claim submitted successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      context.push('/claims/${claim.id}/documents');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to submit claim'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Claim'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() => _currentStep++);
            } else {
              _submitClaim();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Consumer<ClaimsProvider>(
                      builder: (context, provider, _) {
                        return LoadingButton(
                          isLoading: provider.isSubmitting && _currentStep == 2,
                          onPressed: details.onStepContinue,
                          label: _currentStep == 2 ? 'Submit Claim' : 'Continue',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: details.onStepCancel,
                      child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
                    ),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Claim Type'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: _buildStep1(),
            ),
            Step(
              title: const Text('Claim Details'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: _buildStep2(),
            ),
            Step(
              title: const Text('Review & Submit'),
              isActive: _currentStep >= 2,
              state: StepState.indexed,
              content: _buildStep3(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select the type of insurance claim',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        ...AppConstants.claimTypes.map((type) {
          final isSelected = _selectedClaimType == type;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selectedClaimType = type),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.secondaryColor.withOpacity(0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.secondaryColor
                        : AppTheme.dividerColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getTypeIcon(type),
                      color: isSelected
                          ? AppTheme.secondaryColor
                          : AppTheme.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      type,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? AppTheme.secondaryColor
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.secondaryColor,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        CustomTextField(
          controller: _policyController,
          label: 'Policy Number',
          hint: 'POL-XXXXXXXXXX',
          prefixIcon: Icons.policy_outlined,
          validator: Validators.validatePolicyNumber,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _dateController,
          label: 'Incident Date',
          hint: 'Select date',
          prefixIcon: Icons.calendar_today_outlined,
          readOnly: true,
          onTap: _pickDate,
          validator: (v) => Validators.validateRequired(v, 'Incident date'),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _amountController,
          label: 'Claim Amount (₹)',
          hint: '0.00',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: Icons.currency_rupee_rounded,
          validator: Validators.validateAmount,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _descriptionController,
          label: 'Description',
          hint: 'Describe the incident in detail...',
          maxLines: 4,
          validator: (v) => Validators.validateRequired(v, 'Description'),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review your claim details',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _ReviewRow('Claim Type', _selectedClaimType ?? '-'),
          _ReviewRow('Policy Number', _policyController.text.isEmpty ? '-' : _policyController.text),
          _ReviewRow('Incident Date', _dateController.text.isEmpty ? '-' : _dateController.text),
          _ReviewRow('Claim Amount', _amountController.text.isEmpty ? '-' : '₹${_amountController.text}'),
          const SizedBox(height: 8),
          const Text(
            'Description:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _descriptionController.text.isEmpty ? '-' : _descriptionController.text,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.warningColor, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'You will be asked to upload supporting documents after submission.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'health insurance':
        return Icons.health_and_safety_rounded;
      case 'motor insurance':
        return Icons.directions_car_rounded;
      case 'home insurance':
        return Icons.home_rounded;
      case 'life insurance':
        return Icons.favorite_rounded;
      case 'travel insurance':
        return Icons.flight_rounded;
      default:
        return Icons.shield_rounded;
    }
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
