import 'package:flutter/material.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String? title;
  final String? errorCode;
  final bool showTechnicalDetails;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.title,
    this.errorCode,
    this.showTechnicalDetails = false,
  });

  // Factory constructor for API errors
  factory ErrorState.fromApiError(
    dynamic error,
    VoidCallback onRetry, {
    bool showTechnicalDetails = false,
  }) {
    String message;
    String? errorCode;
    String? title;

    if (error is Exception) {
      message = error.toString().replaceAll('Exception: ', '');
      
      // Handle specific error cases
      if (message.contains('Network error')) {
        title = 'Connection Error';
        message = 'Please check your internet connection and try again';
      } else if (message.contains('timeout')) {
        title = 'Request Timeout';
        message = 'The server is taking too long to respond. Please try again';
      } else if (message.contains('404')) {
        title = 'Not Found';
        message = 'The requested resource was not found';
      } else if (message.contains('401')) {
        title = 'Authentication Error';
        message = 'Please log in again to continue';
      } else if (message.contains('403')) {
        title = 'Access Denied';
        message = 'You don\'t have permission to perform this action';
      } else {
        title = 'Error';
      }
    } else {
      title = 'Unexpected Error';
      message = 'An unknown error occurred. Please try again';
    }

    return ErrorState(
      message: message,
      onRetry: onRetry,
      title: title,
      errorCode: errorCode,
      showTechnicalDetails: showTechnicalDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getErrorIcon(),
              size: 64,
              color: _getErrorColor(context),
            ),
            const SizedBox(height: 16),
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _getErrorColor(context),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            if (errorCode != null && showTechnicalDetails) ...[
              const SizedBox(height: 8),
              Text(
                'Error Code: $errorCode',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _buildRetryButton(context),
            if (showTechnicalDetails && message != 'An unknown error occurred. Please try again') ...[
              const SizedBox(height: 16),
              _buildTechnicalDetailsCard(context),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getErrorIcon() {
    if (message.contains('Connection Error') || message.contains('Network error')) {
      return Icons.wifi_off_rounded;
    } else if (message.contains('timeout')) {
      return Icons.timer_off_rounded;
    } else if (message.contains('permission') || message.contains('403')) {
      return Icons.lock_rounded;
    } else if (message.contains('authentication') || message.contains('401')) {
      return Icons.security_rounded;
    } else if (message.contains('not found') || message.contains('404')) {
      return Icons.search_off_rounded;
    }
    return Icons.error_outline_rounded;
  }

  Color _getErrorColor(BuildContext context) {
    if (message.contains('Connection Error') || message.contains('Network error')) {
      return Colors.orange;
    } else if (message.contains('timeout')) {
      return Colors.amber;
    } else if (message.contains('permission') || message.contains('authentication')) {
      return Colors.red;
    }
    return Theme.of(context).colorScheme.error;
  }

  Widget _buildRetryButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Try Again'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _getErrorColor(context),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildTechnicalDetailsCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ExpansionTile(
        title: const Text(
          'Technical Details',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Error Message:', message),
                if (errorCode != null)
                  _buildDetailRow('Error Code:', errorCode!),
                _buildDetailRow('Timestamp:', 
                  DateTime.now().toLocal().toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
          ),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}