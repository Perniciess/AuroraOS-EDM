import 'package:flutter/material.dart';

import '../application/workspace_controller.dart';
import 'common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller, required this.configured});

  final WorkspaceController controller;
  final bool configured;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.controller.busy || !widget.configured || !_form.currentState!.validate()) return;
    final password = _password.text;
    _password.clear();
    FocusScope.of(context).unfocus();
    await widget.controller.login(_username.text, password);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    return Scaffold(
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(key: _form, child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.description_outlined, size: 36,
                  color: theme.colorScheme.onPrimaryContainer),
              )),
              const SizedBox(height: 32),
              Text('АВРОРА / ДОКУМЕНТЫ', style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary, letterSpacing: 1.4)),
              const SizedBox(height: 12),
              Text('Рабочие документы.\nВ вашем ритме.',
                style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text('Войдите с корпоративной учётной записью, чтобы получить назначенные документы.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
              const SizedBox(height: 32),
              if (!widget.configured) ...[
                const MessageCard(message: 'Сервер не настроен. Укажите EDM_API_URL при сборке приложения.'),
                const SizedBox(height: 24),
              ],
              TextFormField(
                controller: _username,
                enabled: !controller.busy,
                decoration: const InputDecoration(labelText: 'Логин', prefixIcon: Icon(Icons.person_outline)),
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                validator: (value) => value == null || value.trim().isEmpty ? 'Введите логин' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !controller.busy,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Пароль', prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Показать пароль' : 'Скрыть пароль',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) => value == null || value.isEmpty ? 'Введите пароль' : null,
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 16),
                MessageCard(message: controller.error!, isError: true),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: controller.busy || !widget.configured ? null : _submit,
                icon: controller.busy
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_forward),
                label: Text(controller.busy ? 'Входим…' : 'Войти в рабочее пространство'),
              ),
              const SizedBox(height: 24),
              Text('Нет доступа? Обратитесь к администратору вашей организации.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          )),
        ),
      ))),
    );
  }
}
