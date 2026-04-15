import 'package:flutter/material.dart';
import '../../../core/theme/k_colors.dart';

/// Industry-specific dashboard configuration.
class DashboardConfig {
  final String industry;
  final String greeting;
  final List<KpiConfig> kpis;
  final List<QuickAction> quickActions;
  final List<WidgetConfig> widgets;

  const DashboardConfig({
    required this.industry,
    required this.greeting,
    required this.kpis,
    required this.quickActions,
    required this.widgets,
  });

  static DashboardConfig forIndustry(String? industry) {
    return switch (industry) {
      'KIRANA' => _kirana,
      'PHARMACY' => _pharmacy,
      'CLOTH_MANUFACTURING' => _clothManufacturing,
      'TRADING' => _trading,
      'FOOD_BEVERAGE' => _foodBeverage,
      'SERVICES' => _services,
      _ => _default,
    };
  }
}

class KpiConfig {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final String endpoint;

  const KpiConfig({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.endpoint,
  });
}

class QuickAction {
  final String label;
  final IconData icon;
  final String route;
  final Color color;

  const QuickAction({
    required this.label,
    required this.icon,
    required this.route,
    required this.color,
  });
}

class WidgetConfig {
  final String id;
  final String title;
  final String type; // 'chart', 'list', 'table'

  const WidgetConfig({
    required this.id,
    required this.title,
    required this.type,
  });
}

// ── Industry Configs ──

const _kirana = DashboardConfig(
  industry: 'KIRANA',
  greeting: 'Namaste',
  kpis: [
    KpiConfig(
      id: 'today_sales',
      title: "Today's Sales",
      icon: Icons.point_of_sale,
      color: KColors.primary,
      endpoint: '/api/v1/dashboard/today-sales',
    ),
    KpiConfig(
      id: 'receivables',
      title: 'Receivables',
      icon: Icons.account_balance_wallet,
      color: KColors.warning,
      endpoint: '/api/v1/dashboard/receivables',
    ),
    KpiConfig(
      id: 'low_stock',
      title: 'Low Stock Items',
      icon: Icons.inventory_2,
      color: KColors.error,
      endpoint: '/api/v1/dashboard/low-stock',
    ),
    KpiConfig(
      id: 'monthly_profit',
      title: 'Monthly Profit',
      icon: Icons.trending_up,
      color: KColors.success,
      endpoint: '/api/v1/dashboard/monthly-profit',
    ),
  ],
  quickActions: [
    QuickAction(
      label: 'New Invoice',
      icon: Icons.receipt_long,
      route: '/invoices/create',
      color: KColors.primary,
    ),
    QuickAction(
      label: 'Record Payment',
      icon: Icons.payments,
      route: '/invoices',
      color: KColors.success,
    ),
    QuickAction(
      label: 'Add Customer',
      icon: Icons.person_add,
      route: '/customers',
      color: KColors.secondary,
    ),
    QuickAction(
      label: 'View Reports',
      icon: Icons.bar_chart,
      route: '/reports',
      color: KColors.accent,
    ),
  ],
  widgets: [
    WidgetConfig(id: 'sales_chart', title: 'Sales This Week', type: 'chart'),
    WidgetConfig(id: 'overdue_invoices', title: 'Overdue Invoices', type: 'list'),
    WidgetConfig(id: 'recent_transactions', title: 'Recent Transactions', type: 'list'),
  ],
);

const _pharmacy = DashboardConfig(
  industry: 'PHARMACY',
  greeting: 'Welcome back',
  kpis: [
    KpiConfig(
      id: 'today_sales',
      title: 'Revenue',
      icon: Icons.point_of_sale,
      color: KColors.primary,
      endpoint: '/api/v1/dashboard/today-sales',
    ),
    KpiConfig(
      id: 'cash_collected',
      title: 'Cash Collected',
      icon: Icons.payments_outlined,
      color: KColors.success,
      endpoint: '/api/v1/dashboard/today-sales',
    ),
    KpiConfig(
      id: 'expiring_stock',
      title: 'Expiring Soon',
      icon: Icons.warning_amber,
      color: KColors.error,
      endpoint: '/api/v1/dashboard/expiring-stock',
    ),
    KpiConfig(
      id: 'receivables',
      title: 'Receivables',
      icon: Icons.account_balance_wallet,
      color: KColors.warning,
      endpoint: '/api/v1/dashboard/receivables',
    ),
  ],
  quickActions: [
    QuickAction(label: 'New Invoice', icon: Icons.receipt_long, route: '/invoices/create', color: KColors.primary),
    QuickAction(label: 'Record Payment', icon: Icons.payments, route: '/invoices', color: KColors.success),
    QuickAction(label: 'Add Customer', icon: Icons.person_add, route: '/customers', color: KColors.secondary),
    QuickAction(label: 'View Reports', icon: Icons.bar_chart, route: '/reports', color: KColors.accent),
  ],
  widgets: [
    WidgetConfig(id: 'sales_chart', title: 'Sales This Week', type: 'chart'),
    WidgetConfig(id: 'expiring_items', title: 'Expiring Items', type: 'list'),
    WidgetConfig(id: 'overdue_invoices', title: 'Overdue Invoices', type: 'list'),
  ],
);

const _clothManufacturing = DashboardConfig(
  industry: 'CLOTH_MANUFACTURING',
  greeting: 'Welcome back',
  kpis: [
    KpiConfig(id: 'monthly_revenue', title: 'Monthly Revenue', icon: Icons.monetization_on, color: KColors.primary, endpoint: '/api/v1/dashboard/monthly-revenue'),
    KpiConfig(id: 'pending_orders', title: 'Pending Orders', icon: Icons.pending_actions, color: KColors.warning, endpoint: '/api/v1/dashboard/pending-orders'),
    KpiConfig(id: 'receivables', title: 'Receivables', icon: Icons.account_balance_wallet, color: KColors.error, endpoint: '/api/v1/dashboard/receivables'),
    KpiConfig(id: 'monthly_profit', title: 'Monthly Profit', icon: Icons.trending_up, color: KColors.success, endpoint: '/api/v1/dashboard/monthly-profit'),
  ],
  quickActions: [
    QuickAction(label: 'New Invoice', icon: Icons.receipt_long, route: '/invoices/create', color: KColors.primary),
    QuickAction(label: 'Record Payment', icon: Icons.payments, route: '/invoices', color: KColors.success),
    QuickAction(label: 'Add Customer', icon: Icons.person_add, route: '/customers', color: KColors.secondary),
    QuickAction(label: 'View Reports', icon: Icons.bar_chart, route: '/reports', color: KColors.accent),
  ],
  widgets: [
    WidgetConfig(id: 'revenue_chart', title: 'Revenue Trend', type: 'chart'),
    WidgetConfig(id: 'overdue_invoices', title: 'Overdue Invoices', type: 'list'),
    WidgetConfig(id: 'recent_transactions', title: 'Recent Transactions', type: 'list'),
  ],
);

const _trading = DashboardConfig(
  industry: 'TRADING',
  greeting: 'Welcome back',
  kpis: [
    KpiConfig(id: 'today_sales', title: "Today's Sales", icon: Icons.point_of_sale, color: KColors.primary, endpoint: '/api/v1/dashboard/today-sales'),
    KpiConfig(id: 'receivables', title: 'Receivables', icon: Icons.account_balance_wallet, color: KColors.warning, endpoint: '/api/v1/dashboard/receivables'),
    KpiConfig(id: 'payables', title: 'Payables', icon: Icons.payment, color: KColors.error, endpoint: '/api/v1/dashboard/payables'),
    KpiConfig(id: 'monthly_profit', title: 'Monthly Profit', icon: Icons.trending_up, color: KColors.success, endpoint: '/api/v1/dashboard/monthly-profit'),
  ],
  quickActions: [
    QuickAction(label: 'New Invoice', icon: Icons.receipt_long, route: '/invoices/create', color: KColors.primary),
    QuickAction(label: 'Record Payment', icon: Icons.payments, route: '/invoices', color: KColors.success),
    QuickAction(label: 'Add Customer', icon: Icons.person_add, route: '/customers', color: KColors.secondary),
    QuickAction(label: 'GST Returns', icon: Icons.account_balance, route: '/gst', color: KColors.accent),
  ],
  widgets: [
    WidgetConfig(id: 'sales_chart', title: 'Sales vs Purchases', type: 'chart'),
    WidgetConfig(id: 'overdue_invoices', title: 'Overdue Invoices', type: 'list'),
    WidgetConfig(id: 'cash_flow', title: 'Cash Flow', type: 'chart'),
  ],
);

const _foodBeverage = DashboardConfig(
  industry: 'FOOD_BEVERAGE',
  greeting: 'Welcome back',
  kpis: [
    KpiConfig(id: 'today_sales', title: "Today's Sales", icon: Icons.point_of_sale, color: KColors.primary, endpoint: '/api/v1/dashboard/today-sales'),
    KpiConfig(id: 'avg_order_value', title: 'Avg Order Value', icon: Icons.receipt, color: KColors.secondary, endpoint: '/api/v1/dashboard/avg-order'),
    KpiConfig(id: 'receivables', title: 'Receivables', icon: Icons.account_balance_wallet, color: KColors.warning, endpoint: '/api/v1/dashboard/receivables'),
    KpiConfig(id: 'monthly_profit', title: 'Monthly Profit', icon: Icons.trending_up, color: KColors.success, endpoint: '/api/v1/dashboard/monthly-profit'),
  ],
  quickActions: [
    QuickAction(label: 'New Invoice', icon: Icons.receipt_long, route: '/invoices/create', color: KColors.primary),
    QuickAction(label: 'Record Payment', icon: Icons.payments, route: '/invoices', color: KColors.success),
    QuickAction(label: 'Add Customer', icon: Icons.person_add, route: '/customers', color: KColors.secondary),
    QuickAction(label: 'View Reports', icon: Icons.bar_chart, route: '/reports', color: KColors.accent),
  ],
  widgets: [
    WidgetConfig(id: 'daily_sales_chart', title: 'Daily Sales', type: 'chart'),
    WidgetConfig(id: 'overdue_invoices', title: 'Overdue Invoices', type: 'list'),
    WidgetConfig(id: 'recent_transactions', title: 'Recent Transactions', type: 'list'),
  ],
);

const _services = DashboardConfig(
  industry: 'SERVICES',
  greeting: 'Welcome back',
  kpis: [
    KpiConfig(id: 'monthly_revenue', title: 'Monthly Revenue', icon: Icons.monetization_on, color: KColors.primary, endpoint: '/api/v1/dashboard/monthly-revenue'),
    KpiConfig(id: 'receivables', title: 'Receivables', icon: Icons.account_balance_wallet, color: KColors.warning, endpoint: '/api/v1/dashboard/receivables'),
    KpiConfig(id: 'overdue_count', title: 'Overdue Invoices', icon: Icons.warning, color: KColors.error, endpoint: '/api/v1/dashboard/overdue-count'),
    KpiConfig(id: 'monthly_profit', title: 'Monthly Profit', icon: Icons.trending_up, color: KColors.success, endpoint: '/api/v1/dashboard/monthly-profit'),
  ],
  quickActions: [
    QuickAction(label: 'New Invoice', icon: Icons.receipt_long, route: '/invoices/create', color: KColors.primary),
    QuickAction(label: 'Record Payment', icon: Icons.payments, route: '/invoices', color: KColors.success),
    QuickAction(label: 'Add Customer', icon: Icons.person_add, route: '/customers', color: KColors.secondary),
    QuickAction(label: 'View Reports', icon: Icons.bar_chart, route: '/reports', color: KColors.accent),
  ],
  widgets: [
    WidgetConfig(id: 'revenue_chart', title: 'Revenue Trend', type: 'chart'),
    WidgetConfig(id: 'overdue_invoices', title: 'Overdue Invoices', type: 'list'),
    WidgetConfig(id: 'client_receivables', title: 'Top Client Receivables', type: 'table'),
  ],
);

const _default = DashboardConfig(
  industry: 'DEFAULT',
  greeting: 'Welcome',
  kpis: [
    KpiConfig(id: 'receivables', title: 'Receivables', icon: Icons.account_balance_wallet, color: KColors.warning, endpoint: '/api/v1/dashboard/receivables'),
    KpiConfig(id: 'monthly_revenue', title: 'Monthly Revenue', icon: Icons.monetization_on, color: KColors.primary, endpoint: '/api/v1/dashboard/monthly-revenue'),
    KpiConfig(id: 'overdue_count', title: 'Overdue Invoices', icon: Icons.warning, color: KColors.error, endpoint: '/api/v1/dashboard/overdue-count'),
    KpiConfig(id: 'monthly_profit', title: 'Monthly Profit', icon: Icons.trending_up, color: KColors.success, endpoint: '/api/v1/dashboard/monthly-profit'),
  ],
  quickActions: [
    QuickAction(label: 'New Invoice', icon: Icons.receipt_long, route: '/invoices/create', color: KColors.primary),
    QuickAction(label: 'Record Payment', icon: Icons.payments, route: '/invoices', color: KColors.success),
    QuickAction(label: 'Add Customer', icon: Icons.person_add, route: '/customers', color: KColors.secondary),
    QuickAction(label: 'View Reports', icon: Icons.bar_chart, route: '/reports', color: KColors.accent),
  ],
  widgets: [
    WidgetConfig(id: 'revenue_chart', title: 'Revenue Trend', type: 'chart'),
    WidgetConfig(id: 'overdue_invoices', title: 'Overdue Invoices', type: 'list'),
    WidgetConfig(id: 'recent_transactions', title: 'Recent Transactions', type: 'list'),
  ],
);
