import 'package:flutter/material.dart';

import '../logic/player_account.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Search field used on the long admin lists.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppText.body(size: 14),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: AppText.caption(),
        filled: true,
        fillColor: AppColors.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _border(AppColors.primaryBase),
      ),
    );
  }
}

/// Sort dropdown. [key] is the field key so tests can open it.
class AdminSortMenu<T> extends StatelessWidget {
  const AdminSortMenu({
    super.key,
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox.shrink(),
        style: AppText.body(size: 13, weight: 800),
        items: [
          for (final item in items)
            DropdownMenuItem(value: item, child: Text(label(item))),
        ],
        onChanged: (next) {
          if (next == null) return;
          onChanged(next);
        },
      ),
    );
  }
}

/// Search on one row, sort and direction on the next, so a 360-wide
/// admin page does not overflow.
class AdminFilterBar extends StatelessWidget {
  const AdminFilterBar({
    super.key,
    required this.search,
    this.sort,
    this.direction,
  });

  final Widget search;
  final Widget? sort;
  final Widget? direction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          if (sort != null || direction != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                ?sort,
                if (sort != null && direction != null) const SizedBox(width: 8),
                ?direction,
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Giảm dần or tăng dần for the sort next to it.
class AdminDirectionButton extends StatelessWidget {
  const AdminDirectionButton({
    super.key,
    required this.ascending,
    required this.onToggle,
  });

  final bool ascending;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return OutlineButton(
      label: ascending ? 'Tăng' : 'Giảm',
      width: 72,
      height: 40,
      onTap: onToggle,
    );
  }
}

/// Trước / Sau under a paged admin list. Hidden by the caller when one
/// page is enough.
class AdminPager extends StatelessWidget {
  const AdminPager({
    super.key,
    required this.page,
    required this.pages,
    required this.total,
    required this.onPage,
    this.prevKey,
    this.nextKey,
  });

  final int page;
  final int pages;
  final int total;
  final ValueChanged<int> onPage;
  final Key? prevKey;
  final Key? nextKey;

  @override
  Widget build(BuildContext context) {
    final start = page * accountPageSize + 1;
    final end = start + accountPageSize - 1;
    final shownEnd = end > total ? total : end;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          OutlineButton(
            key: prevKey,
            label: 'Trước',
            width: 88,
            height: 36,
            onTap: page == 0 ? () {} : () => onPage(page - 1),
          ),
          Expanded(
            child: Text(
              '$start-$shownEnd / $total',
              textAlign: TextAlign.center,
              style: AppText.body(size: 13, weight: 800),
            ),
          ),
          OutlineButton(
            key: nextKey,
            label: 'Sau',
            width: 88,
            height: 36,
            onTap: page >= pages - 1 ? () {} : () => onPage(page + 1),
          ),
        ],
      ),
    );
  }
}

OutlineInputBorder _border([Color? color]) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppRadius.md),
  borderSide: BorderSide(color: color ?? AppColors.surfaceBorder),
);
