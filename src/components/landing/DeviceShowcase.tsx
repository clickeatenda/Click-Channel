import { motion } from "framer-motion";
import { Tv, Smartphone, Tablet, Monitor, Flame } from "lucide-react";

const devices = [
  { icon: Tv, name: "Samsung Smart TV" },
  { icon: Tv, name: "LG WebOS" },
  { icon: Monitor, name: "Android TV" },
  { icon: Flame, name: "Fire TV Stick" },
  { icon: Smartphone, name: "iPhone" },
  { icon: Smartphone, name: "Android" },
  { icon: Tablet, name: "iPad/Tablet" },
  { icon: Monitor, name: "Windows/Mac" },
];

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.08 },
  },
};

const itemVariants = {
  hidden: { opacity: 0, scale: 0.8 },
  visible: { opacity: 1, scale: 1, transition: { duration: 0.4 } },
};

export const DeviceShowcase = () => {
  return (
    <section id="devices" className="py-20 px-4">
      <div className="container mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center mb-12"
        >
          <h2 className="text-3xl md:text-4xl font-bold mb-4">
            Liberdade para assistir{" "}
            <span className="gradient-text">onde quiser</span>
          </h2>
          <p className="text-muted-foreground max-w-2xl mx-auto">
            Compatível com todos os seus dispositivos. Configure uma vez, assista em qualquer lugar.
          </p>
        </motion.div>

        <motion.div
          variants={containerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true }}
          className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-8 gap-4"
        >
          {devices.map((device, index) => (
            <motion.div
              key={device.name}
              variants={itemVariants}
              whileHover={{ scale: 1.1, y: -5 }}
              className="glass rounded-xl p-4 flex flex-col items-center gap-3 cursor-pointer group hover:glow-cyan transition-all duration-300"
            >
              <device.icon className="w-8 h-8 text-muted-foreground group-hover:text-primary transition-colors" />
              <span className="text-xs text-center text-muted-foreground group-hover:text-foreground transition-colors">
                {device.name}
              </span>
            </motion.div>
          ))}
        </motion.div>

        {/* Stats */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6, delay: 0.3 }}
          className="grid grid-cols-3 gap-6 mt-16 max-w-3xl mx-auto"
        >
          {[
            { value: "50.000+", label: "Conteúdos" },
            { value: "10.000+", label: "Clientes Ativos" },
            { value: "99.9%", label: "Uptime" },
          ].map((stat) => (
            <div key={stat.label} className="text-center">
              <p className="text-3xl md:text-4xl font-bold gradient-text">{stat.value}</p>
              <p className="text-sm text-muted-foreground mt-1">{stat.label}</p>
            </div>
          ))}
        </motion.div>
      </div>
    </section>
  );
};
