import { motion } from "framer-motion";
import { Check, Star } from "lucide-react";
import { Button } from "@/components/ui/button";

const plans = [
  {
    name: "Mensal",
    price: "29,90",
    period: "/mês",
    description: "Ideal para testar",
    features: [
      "Liberação Imediata",
      "Todos os canais",
      "Qualidade 4K UHD",
      "Suporte via WhatsApp",
      "Multi-dispositivos",
    ],
    popular: false,
  },
  {
    name: "Trimestral",
    price: "79,90",
    period: "/3 meses",
    description: "Economia + Estabilidade",
    features: [
      "Liberação Imediata",
      "Todos os canais",
      "Qualidade 4K UHD",
      "Suporte Prioritário",
      "Multi-dispositivos",
      "Canais Adultos (Opcional)",
    ],
    popular: true,
  },
  {
    name: "Anual / Revenda",
    price: "Consultar",
    period: "",
    description: "Para quem quer o melhor preço",
    features: [
      "Liberação Imediata",
      "Todos os canais",
      "Qualidade 4K UHD",
      "Suporte VIP Dedicado",
      "Multi-dispositivos",
      "Canais Adultos (Opcional)",
      "Preços especiais para revendedores",
    ],
    popular: false,
  },
];

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.15 },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 40 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.6 } },
};

export const Pricing = () => {
  return (
    <section id="pricing" className="py-20 px-4">
      <div className="container mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center mb-16"
        >
          <h2 className="text-3xl md:text-4xl font-bold mb-4">
            Escolha seu <span className="gradient-text">Plano</span>
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto">
            Investimento acessível para entretenimento ilimitado. Cancele quando quiser.
          </p>
        </motion.div>

        <motion.div
          variants={containerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true }}
          className="grid md:grid-cols-3 gap-6 max-w-5xl mx-auto items-stretch"
        >
          {plans.map((plan) => (
            <motion.div
              key={plan.name}
              variants={itemVariants}
              whileHover={{ scale: 1.02 }}
              className={`relative rounded-2xl p-6 flex flex-col ${
                plan.popular
                  ? "glass-strong ring-2 ring-secondary glow-purple md:scale-105 md:py-10"
                  : "glass"
              }`}
            >
              {plan.popular && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2">
                  <span className="bg-gradient-to-r from-primary to-secondary text-primary-foreground text-xs font-bold px-4 py-1 rounded-full flex items-center gap-1">
                    <Star className="w-3 h-3" /> MAIS VENDIDO
                  </span>
                </div>
              )}

              <div className="text-center mb-6">
                <h3 className="text-xl font-bold mb-2">{plan.name}</h3>
                <p className="text-sm text-muted-foreground mb-4">{plan.description}</p>
                <div className="flex items-baseline justify-center gap-1">
                  {plan.price !== "Consultar" && (
                    <span className="text-lg text-muted-foreground">R$</span>
                  )}
                  <span className={`font-extrabold ${plan.popular ? "text-5xl gradient-text" : "text-4xl"}`}>
                    {plan.price}
                  </span>
                  <span className="text-muted-foreground">{plan.period}</span>
                </div>
              </div>

              <ul className="space-y-3 flex-grow mb-6">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex items-center gap-3 text-sm">
                    <Check className="w-4 h-4 text-primary flex-shrink-0" />
                    <span className="text-muted-foreground">{feature}</span>
                  </li>
                ))}
              </ul>

              <Button
                className={`w-full ${
                  plan.popular
                    ? "btn-gradient glow-cyan"
                    : "bg-muted hover:bg-muted/80 text-foreground"
                }`}
                size="lg"
              >
                {plan.price === "Consultar" ? "Falar no WhatsApp" : "Assinar Agora"}
              </Button>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
};
