import { motion } from "framer-motion";
import { Monitor, Shield, Play, Smartphone } from "lucide-react";

const features = [
  {
    icon: Monitor,
    title: "Qualidade Cinema 4K",
    description: "Conteúdo em FHD e UHD real, com HDR e som cristalino. Experiência de cinema em casa.",
  },
  {
    icon: Shield,
    title: "Tecnologia Anti-Freeze",
    description: "Servidores CDN com canais de backup automático. Caiu um? O outro assume na hora.",
  },
  {
    icon: Play,
    title: "Player VOD Instantâneo",
    description: "Avance, volte e pause filmes e séries sem esperar carregar. Tecnologia MP4 direta.",
  },
  {
    icon: Smartphone,
    title: "Multi-Dispositivos",
    description: "Assista na Smart TV, TV Box, Celular, Tablet ou PC. Liberdade total.",
  },
];

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.15,
    },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 30 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.6 } },
};

export const Features = () => {
  return (
    <section id="features" className="py-20 px-4">
      <div className="container mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center mb-16"
        >
          <h2 className="text-3xl md:text-4xl font-bold mb-4">
            Por que escolher o{" "}
            <span className="gradient-text">Infinity Stream</span>?
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto">
            Tecnologia de ponta para você assistir sem interrupções, com a melhor qualidade do mercado.
          </p>
        </motion.div>

        <motion.div
          variants={containerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true }}
          className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6"
        >
          {features.map((feature) => (
            <motion.div
              key={feature.title}
              variants={itemVariants}
              whileHover={{ scale: 1.05, y: -5 }}
              className="glass rounded-2xl p-6 group cursor-pointer transition-all duration-300 hover:glow-cyan"
            >
              <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-primary/20 to-secondary/20 flex items-center justify-center mb-4 group-hover:from-primary/30 group-hover:to-secondary/30 transition-colors">
                <feature.icon className="w-7 h-7 text-primary group-hover:scale-110 transition-transform" />
              </div>
              <h3 className="text-lg font-semibold mb-2">{feature.title}</h3>
              <p className="text-sm text-muted-foreground">{feature.description}</p>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
};
