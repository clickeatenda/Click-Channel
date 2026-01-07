import { motion } from "framer-motion";

const categories = [
  {
    emoji: "🎭",
    title: "Doramas & K-Dramas",
    description: "A maior coleção do Brasil. Novidades semanais direto da Coreia.",
    image: "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=400&h=250&fit=crop",
    highlight: true,
  },
  {
    emoji: "🌸",
    title: "Animes & Tokusatsus",
    description: "Clássicos e lançamentos. De Dragon Ball a Demon Slayer.",
    image: "https://images.unsplash.com/photo-1578632767115-351597cf2477?w=400&h=250&fit=crop",
    highlight: false,
  },
  {
    emoji: "📺",
    title: "Novelas Completas",
    description: "Nacionais e internacionais. Reviva os clássicos ou maratone as atuais.",
    image: "https://images.unsplash.com/photo-1522869635100-9f4c5e86aa37?w=400&h=250&fit=crop",
    highlight: false,
  },
  {
    emoji: "⚽",
    title: "Esportes Premium",
    description: "Premiere, Libertadores, UFC, Combate e muito mais ao vivo.",
    image: "https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=400&h=250&fit=crop",
    highlight: false,
  },
];

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.1 },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 30 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.5 } },
};

export const ContentCategories = () => {
  return (
    <section id="content" className="py-20 px-4">
      <div className="container mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center mb-16"
        >
          <h2 className="text-3xl md:text-4xl font-bold mb-4">
            Conteúdo <span className="gradient-text">Exclusivo</span>
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto">
            Não é só TV aberta. Acesse conteúdo premium que você não encontra em lugar nenhum.
          </p>
        </motion.div>

        <motion.div
          variants={containerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true }}
          className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6"
        >
          {categories.map((category) => (
            <motion.div
              key={category.title}
              variants={itemVariants}
              whileHover={{ scale: 1.03 }}
              className={`relative rounded-2xl overflow-hidden group cursor-pointer ${
                category.highlight ? "ring-2 ring-secondary glow-purple" : ""
              }`}
            >
              {/* Background Image */}
              <div className="aspect-[4/3] overflow-hidden">
                <img
                  src={category.image}
                  alt={category.title}
                  className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-500"
                />
              </div>

              {/* Overlay */}
              <div className="absolute inset-0 bg-gradient-to-t from-black via-black/50 to-transparent" />

              {/* Content */}
              <div className="absolute inset-0 p-5 flex flex-col justify-end">
                {category.highlight && (
                  <span className="absolute top-3 right-3 bg-secondary text-secondary-foreground text-xs font-bold px-2 py-1 rounded-full">
                    DESTAQUE
                  </span>
                )}
                <span className="text-2xl mb-2">{category.emoji}</span>
                <h3 className="text-lg font-bold text-white mb-1">{category.title}</h3>
                <p className="text-xs text-white/70">{category.description}</p>
              </div>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
};
