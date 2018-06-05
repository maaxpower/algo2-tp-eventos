package ar.edu.usuarios

import ar.edu.eventos.Evento
import ar.edu.eventos.EventoAbierto
import ar.edu.eventos.EventoCerrado
import ar.edu.eventos.exceptions.BusinessException
import ar.edu.notificaciones.Notificacion
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.ArrayList
import java.util.Collection
import java.util.List
import java.util.Set
import org.eclipse.xtend.lib.annotations.Accessors
import org.uqbar.ccService.CCResponse
import org.uqbar.ccService.CreditCard
import org.uqbar.ccService.CreditCardService
import org.uqbar.geodds.Point
import org.uqbar.mailService.Mail
import org.uqbar.mailService.MailService

@Accessors
class Usuario {
	int id = -1 
	String nombreUsuario
	String nombreApellido
	String mail
	LocalDate fechaNacimiento
	Direccion direccion
	boolean esAntisocial
	double radioCercania
	Set<Usuario> amigos = newHashSet
	LocalDateTime fechaHoraActual
	TipoUsuario tipoUsuario;
	double saldoAFavor = 0
	Collection<Evento> eventosOrganizados = new ArrayList<Evento>
	Set<Invitacion> invitaciones = newHashSet
	CreditCard miTarjeta
	//PagoConTarjeta nuevoPago
	CreditCardService servicioTarjeta
	List<Profesional> AConfirmar = newArrayList
	Set<Profesional> ARechazar = newHashSet
	List<Notificacion> tiposNotificaciones = newArrayList
	MailService servicioMail
	List<String> listaArtistasFan
	
	def setDireccion(String calle, int numero, String localidad, String provincia, Point punto){
		direccion = new Direccion(calle, numero, localidad, provincia, punto)
	}
	
	def edad(){		//cambiar variable edad por metodo edad en tests
		Duration.between(LocalDateTime.of(fechaNacimiento, fechaHoraActual.toLocalTime), fechaHoraActual).getSeconds() / 31536000
	}
	
	// Organizador
	def cambiarTipo(TipoUsuario unTipoUsuario){
		tipoUsuario = unTipoUsuario
	}
	
	//Solo puede realizar invitaciones si la cantidad acompaniantes de la nueva invitacion + la cantidad de posibles asistentes no supera 
	//capacidad maxima, de esta forma el usuario puede confirmar siempre y cuando este a tiempo
	def invitarUsuario(Usuario invitado, EventoCerrado unEvento, Integer cantidadAcompaniantesMaxima) {		
		if(checkCondicionesParaInvitar(unEvento, cantidadAcompaniantesMaxima))	//Se chequea las condiciones de cada tipoUsuario
			this.realizarInvitacion(invitado, unEvento, cantidadAcompaniantesMaxima)
		else
			throw new BusinessException("No se puede realizar invitacion, el evento llego a su maxima capacidad o alcanzo 
				la cantidad maxima de invitaciones/invitados")
	}
	
	def boolean checkCondicionesParaInvitar(EventoCerrado unEvento, Integer cantidadAcompaniantesMaxima) {
		eventosOrganizados.contains(unEvento) && unEvento.chequearCapacidad(cantidadAcompaniantesMaxima) && tipoUsuario.puedeInvitarUsuario(unEvento, cantidadAcompaniantesMaxima)
	}
	
	def realizarInvitacion(Usuario invitado, EventoCerrado unEvento, Integer cantidadAcompaniantesMaxima) {
		var unaInvitacion = new Invitacion(invitado, unEvento, cantidadAcompaniantesMaxima)				
		unaInvitacion.usuarioRecibeInvitacion()
	}
	// EN tipo free => !unEvento.class.toString.equals("ar.edu.eventos.EventoAbierto") && !tipoUsuario.toString.equals("ar.edu.usuarios.Free@707f7052")
	def crearEvento(Evento unEvento){		//En test creo el evento primero(para inicializar
		if( this.puedoCrearEvento(unEvento)){		//variables y luego se lo paso como parametro a
			unEvento.setFechaCreacionyOrganizador(this)	//usuario organizador que es el que cuando lo "crea"
			this.agregarEventoLista(unEvento)	//se setean la fecha de creacio y organizador
			this.enviarNotificaciones()
		}
		else
			throw new BusinessException("Error no se puede crear evento")
	}
	
	def enviarNotificaciones() {
		tiposNotificaciones.forEach(notificacion |  notificacion.enviar(this))
	}
	
	def agregarTipoNotificacion(Notificacion nuevaNotifiacion){
		tiposNotificaciones.add(nuevaNotifiacion)
	}
	
	def boolean puedoCrearEvento(Evento evento){
		tipoUsuario.puedoOrganizarEvento(this, evento)
	}
	
	def void agregarEventoLista(Evento unEvento){
		eventosOrganizados.add(unEvento)
	}
	
	def cancelarEvento(Evento unEvento){
		tipoUsuario.cancelarEvento(unEvento)
	}
	
	def postergarEvento(Evento unEvento, LocalDateTime nuevaFechaInicio){
		tipoUsuario.postergarEvento(unEvento, nuevaFechaInicio)
	}
	
	def cantidadEventosSimultaneos() {
		this.eventosOrganizados.filter[evento | this.fechaHoraActual.isBefore(evento.finEvento) ].size //fecha creacion evento = fecha actual del usuario	
	}
	
	def cantidadEventosOrganizadosMes() {
		this.eventosOrganizados.filter[evento | evento.fechaCreacion.month == this.fechaHoraActual.month 
			|| evento.finEvento.month == this.fechaHoraActual.month].size
	}
//Usuario evento cerrado

	def agregarInvitacionLista(Invitacion unaInvitacion){
		invitaciones.add(unaInvitacion)
		println(this.nombreUsuario + " tiene una nueva invitacion para el evento " + unaInvitacion.evento.nombreEvento)
	}
	
	//Se recibe unEvento que funciona como una clave y luego se obtiene la invitacion
	
	//CAMBIADO***** La accion se realiza por "TipoDeUsuario" de por medio
	def confirmarInvitacion(EventoCerrado unEvento, Integer invitados) { // la cantidad de acompaniantes
		var unaInvitacion = this.eventoInvitacion(unEvento)
		if (tipoUsuario != null){
			tipoUsuario.aceptarInvitacion(this, unEvento, invitados)
			}
		else if (unaInvitacion !== null){
			unaInvitacion.confirmar(invitados)
			}
	}

	// CAMBIADO***** La accion se realiza por "TipoDeUsuario" de por medio
	def rechazarInvitacion(EventoCerrado unEvento) {
		var unaInvitacion = this.eventoInvitacion(unEvento)
		if (tipoUsuario != null)
			tipoUsuario.rechazarInvitacion(this, unEvento)
		else if (unaInvitacion !== null)
			unaInvitacion.rechazar()
	}
	//Nuevo
	def eventoInvitacion(EventoCerrado unEvento ){
		invitaciones.findFirst(invitacion | invitacion.evento == unEvento)//obtengo la invitacion con el evento
	}
	

	def comprarEntrada(EventoAbierto unEvento) {	
		val CCResponse response = servicioTarjeta.pay(miTarjeta, unEvento.valorEntrada)
		if(response.statusCode != 0) {
			throw new BusinessException(response.statusMessage)
		}
		unEvento.usuarioCompraEntrada(this)
		println(response.statusMessage)
	}
	
	def devolverEntrada(EventoAbierto unEvento) {
		if(unEvento.estaInvitado(this) && unEvento.diasfechaMaximaConfirmacion(this) > 0){
			unEvento.devolverDinero(this)
			unEvento.removerUsuario(this)
		}
		else
			throw new BusinessException("Error: usuario no puede devolver entrada")
	}
	
	
	def aceptarPendientes() {
		this.filtrarInvitacionesCumplenCondicionesPendientes.forEach [ invitacion |
			this.confirmarInvitacion(invitacion.evento, invitacion.cantidadAcompaniantesMaxima)]
	}

	def filtrarInvitacionesCumplenCondicionesPendientes() {
		invitaciones.filter[invitacion|this.cumpleCondicionPendientes(invitacion.evento)]
	}

	def boolean cumpleCondicionPendientes(EventoCerrado unEvento) {
		(this.organizadorEsAmigo(unEvento.organizador)) || this.asistenMasDeCuatroAmigos(unEvento) ||
			this.eventoEstaCerca(unEvento)
	}

	def boolean eventoEstaCerca(Evento evento) {
		evento.distancia(direccion.coordenadas) <= radioCercania
	}

	def boolean asistenMasDeCuatroAmigos(EventoCerrado invitacion) {
		this.cantidadAmigosConfirmadosEvento(invitacion) >= 4
	}

	def cantidadAmigosConfirmadosEvento(EventoCerrado invitacion) {
		amigos.filter(amigo|invitacion.estaConfirmado(amigo)).size
	}

	def boolean organizadorEsAmigo(Usuario organizador) {
		amigos.contains(organizador)
	}

	def agregarAmigo(Usuario unAmigo) {
		amigos.add(unAmigo)
	}
	
	def rechazarPendientes() {
		if(esAntisocial)
			this.antisocialRechazarPendientes
		else
			this.noAntisocialRechazarPendientes
	}
	
	def noAntisocialRechazarPendientes() {
		this.pendientesParaRechazarQueCumplenCondicionNoAntisocial.forEach[invitacion | this.rechazarInvitacion(invitacion.evento)]
	}
	
	def pendientesParaRechazarQueCumplenCondicionNoAntisocial() {
		invitaciones.filter[invitacion| this.cumpleCondicionesNoAntisocial(invitacion.evento)]
	}
	
	def boolean cumpleCondicionesNoAntisocial(EventoCerrado unEvento){
		!this.eventoEstaCerca(unEvento) || this.noAsistenAmigos(unEvento)
	}
	
	def boolean noAsistenAmigos(EventoCerrado invitacion) {
		this.cantidadAmigosConfirmadosEvento(invitacion) == 0
	}
	
	def antisocialRechazarPendientes() {
		this.pendientesParaRechazarQueCumplenCondicionAntisocial.forEach[invitacion | this.rechazarInvitacion(invitacion.evento)]
	}
	
	def pendientesParaRechazarQueCumplenCondicionAntisocial() {
		invitaciones.filter[invitacion| this.cumpleCondicionesAntisocial(invitacion.evento)]
	}
	
	def boolean cumpleCondicionesAntisocial(EventoCerrado unEvento) {
		!this.eventoEstaCerca(unEvento) || this.asistenAlMenosDosAmigos(unEvento)
	}

	def boolean asistenAlMenosDosAmigos(EventoCerrado invitacion) {
		this.cantidadAmigosConfirmadosEvento(invitacion) <= 2
	}
	
	def notificacionEventoCancelado() {
		println("El evento fue cancelado.")
	}
	
	def notificacionEventoPostergado(Evento unEvento) {
		println("El evento "+unEvento.nombreEvento+" fue postergado.")
		println("Las nuevas fechas son")
		println("Fecha maxima confirmacion: "+unEvento.fechaMaximaConfirmacion)
		println("Fecha Inicio: "+ unEvento.inicioEvento)
		println("Fecha fin: "+unEvento.finEvento)
	}	
   def agregarInvitacionAceptada (Profesional unProfe){
   	AConfirmar.add(unProfe)
   }
   def agregarInvitacionRechazada(Profesional unProfe){
   	ARechazar.add(unProfe)
   }

//////////NUEVO
   def cambiarDesicionDeUnAceptado(EventoCerrado unEvento){
   val aCambiar=AConfirmar.findFirst(repaso | repaso.auxEvento == unEvento)
    if(aCambiar===null)
    throw new BusinessException ("Invitacion no encontrada")else
    unEvento.removerUsuarioAconfirmar(aCambiar)
     unEvento.agregarUsuariosArechazar(aCambiar)
}
   def cambiarDesicionDeUnRechazado(EventoCerrado unEvento){
   val aCambiar=ARechazar.findFirst(repaso | repaso.auxEvento == unEvento)
  
   if(aCambiar===null)
    throw new BusinessException ("Invitacion no encontrada")else
    
      unEvento.agregarUsuarioAconfirmar(aCambiar)
      unEvento.removerUsuariosArechazar(aCambiar)
//////////////////
	}
	def recibirNotificacion(Usuario organizador) {
		println(nombreUsuario+": El usuario "+organizador.nombreUsuario+" creo el evento "+organizador.ultimoEventoOrganizado.nombreEvento)
	}
	
	def ultimoEventoOrganizado() {
		eventosOrganizados.last
	}
	
	def enviarMailA(Usuario contacto){
		servicioMail.sendMail(new Mail =>[
			to = contacto.mail
			from = this.mail
			subject = "Nuevo evento cerca"
			text = "El usuario "+contacto.nombreUsuario+"creo el evento "+this.ultimoEventoOrganizado()
		])
	}
	
	def esFanDe(String artista) {
		listaArtistasFan.contains(artista)
	}
	
	def recibirNotificacionArtista(String artista,  Evento evento) {
		println("El artista "+artista+"se presentara en el evento "+evento.nombreEvento )
	}
}