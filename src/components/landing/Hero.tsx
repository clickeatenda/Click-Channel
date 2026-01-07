import { motion } from "framer-motion";
import { Play, List } from "lucide-react";
import { Button } from "@/components/ui/button";

export const Hero = () => {
  return (
    <section className="min-h-screen flex items-center justify-center pt-20 pb-16 px-4">
      <div className="container mx-auto">
        <div className="grid lg:grid-cols-2 gap-12 items-center">
          {/* Text Content */}
          <motion.div
            initial={{ opacity: 0, x: -50 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8 }}
            className="text-center lg:text-left"
          >
            <motion.span
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2 }}
              className="inline-block px-4 py-2 rounded-full glass text-primary text-sm font-medium mb-6"
            >
              🚀 +50.000 Conteúdos em 4K UHD
            </motion.span>

            <motion.h1
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
              className="text-4xl md:text-5xl lg:text-6xl font-extrabold leading-tight mb-6"
            >
              Sua TV{" "}
              <span className="gradient-text">Nunca Mais</span>{" "}
              Será a Mesma
            </motion.h1>

            <motion.p
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4 }}
              className="text-lg text-muted-foreground mb-8 max-w-xl mx-auto lg:mx-0"
            >
              Acesse mais de 50.000 conteúdos em 4K UHD. Filmes, Séries, Futebol e a{" "}
              <span className="text-secondary font-semibold">maior coleção de Doramas do Brasil</span>.
              Sem travamentos, sem complicação.
            </motion.p>

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.5 }}
              className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start"
            >
              <Button size="lg" className="btn-gradient glow-cyan text-lg px-8 py-6 hover:scale-105 transition-transform">
                <Play className="w-5 h-5 mr-2" />
                Liberar Acesso VIP
              </Button>
              <Button size="lg" variant="outline" className="btn-outline-glow text-lg px-8 py-6 hover:scale-105 transition-transform">
                <List className="w-5 h-5 mr-2" />
                Ver Lista de Canais
              </Button>
            </motion.div>

            {/* Trust Badges */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.7 }}
              className="flex items-center gap-6 mt-10 justify-center lg:justify-start text-sm text-muted-foreground"
            >
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                <span>Servidores Online</span>
              </div>
              <div className="flex items-center gap-2">
                <span>⭐ 4.9/5</span>
                <span>+10.000 clientes</span>
              </div>
            </motion.div>
          </motion.div>

          {/* TV Mockup */}
          <motion.div
            initial={{ opacity: 0, x: 50 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.8, delay: 0.3 }}
            className="relative"
          >
            <div className="relative animate-float">
              {/* TV Frame */}
              <div className="relative rounded-3xl overflow-hidden glass-strong p-2 glow-purple">
                <img
                  src="https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?w=800&h=500&fit=crop"
                  alt="Smart TV com interface de streaming"
                  className="rounded-2xl w-full aspect-video object-cover"
                />
                {/* Overlay with interface elements */}
                <div className="absolute inset-2 rounded-2xl bg-gradient-to-t from-black/60 via-transparent to-transparent flex items-end p-6">
                  <div className="text-white">
                    <p className="text-xs text-primary mb-1">EM DESTAQUE</p>
                    <h3 className="text-xl font-bold">The Glory</h3>
                    <p className="text-sm text-white/70">K-Drama • 2023 • 4K UHD</p>
                  </div>
                </div>
              </div>

              {/* Floating Elements */}
              <motion.div
                animate={{ y: [0, -10, 0] }}
                transition={{ duration: 2, repeat: Infinity, delay: 0.5 }}
                className="absolute -top-4 -right-4 glass px-4 py-2 rounded-full text-sm font-medium"
              >
                🔥 4K UHD
              </motion.div>

              <motion.div
                animate={{ y: [0, 10, 0] }}
                transition={{ duration: 2.5, repeat: Infinity }}
                className="absolute -bottom-4 -left-4 glass px-4 py-2 rounded-full text-sm font-medium"
              >
                🎭 +5.000 Doramas
              </motion.div>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
};
