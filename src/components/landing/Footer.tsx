import { Zap } from "lucide-react";

const footerLinks = [
  { href: "#features", label: "Diferenciais" },
  { href: "#content", label: "Conteúdo" },
  { href: "#devices", label: "Dispositivos" },
  { href: "#pricing", label: "Planos" },
  { href: "#faq", label: "FAQ" },
];

export const Footer = () => {
  return (
    <footer className="py-12 px-4 border-t border-border">
      <div className="container mx-auto">
        <div className="flex flex-col md:flex-row items-center justify-between gap-6">
          {/* Logo */}
          <div className="flex items-center gap-2">
            <Zap className="w-6 h-6 text-primary" />
            <span className="text-lg font-bold gradient-text">Infinity Stream</span>
          </div>

          {/* Links */}
          <nav className="flex flex-wrap justify-center gap-6">
            {footerLinks.map((link) => (
              <a
                key={link.href}
                href={link.href}
                className="text-sm text-muted-foreground hover:text-foreground transition-colors"
              >
                {link.label}
              </a>
            ))}
          </nav>

          {/* Copyright */}
          <p className="text-sm text-muted-foreground">
            © 2025 Infinity Stream. Todos os direitos reservados.
          </p>
        </div>
      </div>
    </footer>
  );
};
